//
//  GeocodeNavigationBar.swift
//  iBurn
//
//  Shows the user's current playa address in a screen's navigation bar. Lived in
//  `SortedViewController.swift` (Yap list stack) and `BRCGeocoder.m` (Mantle-era
//  Objective-C) until the YapDatabase removal; the behaviour is unchanged.
//

import UIKit
import CoreLocation
import PlayaGeocoder

extension CLLocation {
    /// The device's last known location, from the app delegate's shared location manager.
    static var currentLocation: CLLocation? {
        BRCAppDelegate.shared.locationManager.location
    }
}

extension String {
    /// The playa address prefixed with a crosshairs (SF Symbol `scope`) glyph.
    var brc_attributedLocationStringWithCrosshairs: NSAttributedString {
        let colors = Appearance.currentColors
        let string = NSMutableAttributedString()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17)
        if let crosshairs = UIImage(systemName: "scope", withConfiguration: symbolConfig)?
            .withTintColor(colors.detailColor, renderingMode: .alwaysOriginal) {
            string.append(NSAttributedString(attachment: NSTextAttachment(image: crosshairs)))
        }
        string.append(NSAttributedString(string: " "))
        string.append(NSAttributedString(
            string: self,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: colors.primaryColor
            ]
        ))
        return string
    }
}

extension UIViewController {
    /// Adds the current geocoded playa address to the navigation bar title.
    func geocodeNavigationBar() {
        // Always use the real location for navigation bar
        guard let location = CLLocation.currentLocation else { return }
        PlayaGeocoder.shared.asyncReverseLookup(location.coordinate) { [weak self] locationString in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let locationString = locationString, !locationString.isEmpty {
                    let label = UILabel()
                    label.attributedText = locationString.brc_attributedLocationStringWithCrosshairs
                    label.sizeToFit()
                    self.navigationItem.titleView = label
                } else {
                    self.navigationItem.title = self.title
                }
            }
        }
    }
}
