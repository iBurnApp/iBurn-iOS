//
//  DroppedPersonAnnotation.swift
//  iBurn
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The little "person" the user drops on the main map with a long press, à la Street
//  View's pegman. While it is standing somewhere, the map's nearby card (and the Nearby
//  screen reached from it) source their content and distances from the person's
//  coordinate instead of the device's.
//
//  Deliberately NOT a `BRCMapPoint`/`BRCUserMapPoint`: those are the user's saved pins and
//  are written to PlayaDB. This one is ephemeral — it exists only as an annotation on a
//  live map view, is never persisted, and dies with the session.
//

import CoreLocation
import MapLibre
import UIKit

/// Transient map annotation representing "look at the playa from here".
///
/// `MLNPointAnnotation` gives it the settable `coordinate`/`title` the callout needs;
/// `ImageAnnotation` is what makes `MapViewAdapter` render it with a custom image.
final class DroppedPersonAnnotation: MLNPointAnnotation {

    /// Distinct from `ImageAnnotationView.reuseIdentifier` so the person's view is never
    /// recycled as an ordinary pin (or vice versa) — the two carry different images and
    /// different draggability.
    static let reuseIdentifier = "DroppedPersonAnnotationView"

    /// Fallback callout title before (or without) a reverse-geocoded playa address.
    static let fallbackTitle = NSLocalizedString(
        "Dropped pin",
        comment: "callout title for the dropped person marker when no playa address is known"
    )

    /// Held per-instance rather than in a static: only one person is ever on the map at a
    /// time, and an instance property sidesteps shared mutable state entirely.
    private let image: UIImage

    init(coordinate: CLLocationCoordinate2D, title: String?) {
        self.image = DroppedPersonMarker.makeImage()
        super.init()
        self.coordinate = coordinate
        self.title = title ?? Self.fallbackTitle
    }

    /// `MLNPointAnnotation` is `NSCoding`; this marker never round-trips through an archive
    /// (it isn't persisted anywhere), so the inherited requirement is satisfied by rebuilding
    /// the artwork and letting the superclass restore the coordinate and title.
    required init?(coder: NSCoder) {
        self.image = DroppedPersonMarker.makeImage()
        super.init(coder: coder)
    }
}

extension DroppedPersonAnnotation: ImageAnnotation {
    var markerImage: UIImage? { image }
}

// MARK: - Coordinate identity

extension CLLocationCoordinate2D {
    /// Exact coordinate match.
    ///
    /// Used to tie an asynchronous reverse-geocode result back to the drop that asked for
    /// it: the coordinate round-trips through a `CLLocation` untouched, so an exact compare
    /// is both correct and the strictest available staleness check. Deliberately a named
    /// method rather than an `Equatable` conformance on a Foundation type.
    func isSameCoordinate(as other: CLLocationCoordinate2D) -> Bool {
        latitude == other.latitude && longitude == other.longitude
    }
}

/// Identity for an optional source location: two nils are the same source.
func isSameSourceLocation(_ lhs: CLLocation?, _ rhs: CLLocation?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): true
    case let (l?, r?): l.coordinate.isSameCoordinate(as: r.coordinate)
    default: false
    }
}

// MARK: - Marker artwork

/// Draws the marker: an open eye — "look at the playa from here" — inside a circular chip. A
/// saturated fill with a white ring and a drop shadow reads on both the light (tan) and dark
/// playa base maps, where a bare glyph would not.
///
/// The eye replaced the Burning Man figure ("the Man") that the marker used to composite from
/// the `pin_center` imageset: that artwork is trademarked, and reusing it as a general-purpose
/// UI glyph is a use the app shouldn't make of it. The imageset itself stays — the map style's
/// Man POI still draws it — but nothing in this feature touches it any more.
enum DroppedPersonMarker {

    /// Chip diameter in points. Big enough to be an easy tap target for its callout,
    /// small enough not to blanket the camps it is standing among.
    static let diameter: CGFloat = 34

    /// The marker's glyph, as an SF Symbol. Public so the surfaces that explain the drop —
    /// the nearby card's header, the Nearby screen's banner — can prefix themselves with the
    /// same mark the user sees standing on the map.
    static let glyphSymbolName = "eye.fill"

    /// Point size the symbol is requested at. SF Symbols return an image a little larger than
    /// their point size, and `eye.fill` is much wider than it is tall, so the drawn size is
    /// derived by aspect-fitting into `glyphBoxSide` rather than used directly.
    private static let glyphPointSize: CGFloat = 20

    /// The square the glyph is fitted inside, centered in the chip. 20 pt across the 29 pt
    /// face leaves the eye a comfortable margin without shrinking it to a dot.
    private static let glyphBoxSide: CGFloat = 20

    /// Room around the chip for the shadow, so it isn't clipped by the image bounds.
    private static let shadowPadding: CGFloat = 5

    private static let ringWidth: CGFloat = 2.5

    /// Deliberately not a theme color: the marker has to stay legible against both map
    /// themes, and the app's amber accent sits close to the light base map's tan.
    private static let fillColor = UIColor(red: 0.16, green: 0.42, blue: 0.93, alpha: 1)

    static func makeImage() -> UIImage {
        let side = diameter + shadowPadding * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            let chipRect = CGRect(x: shadowPadding, y: shadowPadding, width: diameter, height: diameter)

            // White ring, carrying the shadow.
            cg.saveGState()
            cg.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 3,
                color: UIColor.black.withAlphaComponent(0.35).cgColor
            )
            UIColor.white.setFill()
            UIBezierPath(ovalIn: chipRect).fill()
            cg.restoreGState()

            // Colored face.
            fillColor.setFill()
            UIBezierPath(ovalIn: chipRect.insetBy(dx: ringWidth, dy: ringWidth)).fill()

            // Drawn at its natural aspect ratio — `eye.fill` is roughly 3:2, and squaring it
            // off would visibly squash the pupil.
            if let glyph = makeGlyph() {
                let glyphSize = fittedGlyphSize(for: glyph.size)
                let glyphRect = CGRect(
                    x: chipRect.midX - glyphSize.width / 2,
                    y: chipRect.midY - glyphSize.height / 2,
                    width: glyphSize.width,
                    height: glyphSize.height
                )
                glyph.draw(in: glyphRect)
            }
        }
        // The annotation view's image view would otherwise tint a template image with the
        // map's tint color and lose the chip entirely.
        return image.withRenderingMode(.alwaysOriginal)
    }

    /// The white eye, ready to be composited onto the chip.
    ///
    /// `alwaysOriginal` so the white survives whatever tint the annotation view's image view
    /// would otherwise apply.
    static func makeGlyph() -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .semibold)
        return UIImage(systemName: glyphSymbolName, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }

    /// Aspect-fits `size` into the glyph box. Exposed for tests: the whole point of fitting
    /// rather than scaling by height is that a wide symbol still lands inside the chip's face.
    static func fittedGlyphSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: glyphBoxSide, height: glyphBoxSide)
        }
        let scale = min(glyphBoxSide / size.width, glyphBoxSide / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
