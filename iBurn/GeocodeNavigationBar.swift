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
import BButton
import PlayaGeocoder

extension CLLocation {
    /// The device's last known location, from the app delegate's shared location manager.
    static var currentLocation: CLLocation? {
        BRCAppDelegate.shared.locationManager.location
    }
}

extension String {
    /// The playa address prefixed with a Font Awesome crosshairs glyph.
    var brc_attributedLocationStringWithCrosshairs: NSAttributedString {
        let colors = Appearance.currentColors
        let string = NSMutableAttributedString()
        let crosshairsFont = UIFont(name: kFontAwesomeFont, size: 17) ?? UIFont.systemFont(ofSize: 17)
        string.append(NSAttributedString(
            string: NSString.fa_string(forFontAwesomeIcon: .FACrosshairs),
            attributes: [.font: crosshairsFont, .foregroundColor: colors.detailColor]
        ))
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
