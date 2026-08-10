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

/// Draws the marker: the Man himself, standing in a circular chip. A saturated fill with a
/// white ring and a drop shadow reads on both the light (tan) and dark playa base maps,
/// where a bare glyph would not.
enum DroppedPersonMarker {

    /// Chip diameter in points. Big enough to be an easy tap target for its callout,
    /// small enough not to blanket the camps it is standing among.
    static let diameter: CGFloat = 34

    /// The Man, as already shipped for the map's center pin.
    ///
    /// The imageset is appearance-scoped — black artwork for light, white for dark — and is
    /// not configured as a template, so the chip asks for the dark (white) variant *and*
    /// re-colors it: `withTintColor` treats the artwork as an alpha mask, so the glyph comes
    /// out crisp white whichever variant the catalog hands back.
    static let glyphAssetName = "pin_center"

    /// How tall the Man stands inside the chip. The artwork is a touch wider than it is tall
    /// (1000×950), so the width follows from its own aspect ratio rather than being squared
    /// off — 20pt tall leaves a comfortable margin inside the 29pt face.
    private static let glyphHeight: CGFloat = 20

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

            // The Man, drawn at his natural aspect ratio — squeezing him into a square
            // would visibly stretch the arms.
            if let glyph = makeGlyph() {
                let aspectRatio = glyph.size.height > 0 ? glyph.size.width / glyph.size.height : 1
                let glyphSize = CGSize(width: glyphHeight * aspectRatio, height: glyphHeight)
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

    /// The white Man, ready to be composited onto the chip.
    ///
    /// Falls back to the SF Symbol the marker used before the asset was wired up, so a
    /// catalog miss degrades to a person rather than to an empty blue dot.
    static func makeGlyph() -> UIImage? {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        if let asset = UIImage(named: glyphAssetName, in: nil, compatibleWith: darkTraits) {
            return asset.withTintColor(.white, renderingMode: .alwaysOriginal)
        }
        let configuration = UIImage.SymbolConfiguration(pointSize: diameter * 0.58, weight: .semibold)
        return UIImage(systemName: "figure.stand", withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}
