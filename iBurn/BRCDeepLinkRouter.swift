//
//  BRCDeepLinkRouter.swift
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import UIKit
import CoreLocation
import CocoaLumberjack
import PlayaDB

enum DeepLinkObjectType: String {
    case art = "art"
    case camp = "camp"
    case event = "event"
    case pin = "pin"
}

@objc class BRCDeepLinkRouter: NSObject {
    
    @objc static let shared = BRCDeepLinkRouter()
    
    private weak var tabController: TabController?
    
    @objc func configure(withTabController tabController: TabController) {
        self.tabController = tabController
    }
    
    // MARK: - URL Handling
    
    @objc func canHandleURL(_ url: URL) -> Bool {
        if url.scheme == "iburn" {
            return true
        }
        if url.host == "iburnapp.com" || url.host == "www.iburnapp.com" {
            return true
        }
        return false
    }
    
    @objc func handleURL(_ url: URL) -> Bool {
        DDLogInfo("Deep link router handling URL: \(url.absoluteString)")
        guard canHandleURL(url) else { 
            DDLogWarn("Cannot handle URL: \(url.absoluteString)")
            return false 
        }
        
        // Extract the type component based on URL scheme
        let typeComponent: String?
        
        if url.scheme == "iburn" {
            // For iburn:// URLs, the host IS the type (e.g., iburn://art?uid=123)
            typeComponent = url.host
            DDLogInfo("iburn:// scheme - using host as type: \(typeComponent ?? "nil")")
        } else {
            // For https URLs, use path components (e.g., https://iburnapp.com/art/?uid=123)
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            typeComponent = pathComponents.first
            DDLogInfo("https scheme - using path component as type: \(typeComponent ?? "nil")")
        }
        
        guard let firstComponent = typeComponent else { 
            DDLogWarn("No type component found in URL: \(url.absoluteString)")
            return false 
        }
        
        // Parse query parameters
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let metadata = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        
        DDLogInfo("Type component: \(firstComponent)")
        switch firstComponent {
        case "art", "camp", "event":
            // UID is now a query parameter
            guard let uid = metadata["uid"] else { 
                DDLogWarn("No UID found in metadata for \(firstComponent)")
                return false 
            }
            DDLogInfo("Navigating to \(firstComponent) with UID: \(uid)")
            return navigateToObject(uid: uid, type: firstComponent, metadata: metadata)
            
        case "pin":
            DDLogInfo("Creating map pin from metadata")
            return createMapPin(from: metadata)
            
        default:
            DDLogWarn("Unknown type component: \(firstComponent)")
            return false
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToObject(uid: String, type: String, metadata: [String: String]) -> Bool {
        guard let tabController = tabController else { return false }

        Task { @MainActor in
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            var detailVC: UIViewController?
            switch type {
            case "art":
                if let art = try? await playaDB.fetchArt(uid: uid) {
                    detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
                }
            case "camp":
                if let camp = try? await playaDB.fetchCamp(uid: uid) {
                    detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
                }
            case "event":
                if let event = try? await playaDB.fetchEvent(uid: uid) {
                    detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
                }
            default:
                break
            }

            guard let vc = detailVC else {
                DDLogWarn("Object not found for UID: \(uid) type: \(type)")
                self.showObjectNotFound(uid: uid, type: type, metadata: metadata)
                return
            }

            DDLogInfo("Found object for UID: \(uid)")

            // Wrap in navigation controller for sheet presentation
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .pageSheet

            // Add close button to navigation bar
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(self.dismissDetailSheet)
            )

            // Present over current interface
            if let presentedVC = tabController.presentedViewController {
                presentedVC.present(navController, animated: true)
            } else {
                tabController.present(navController, animated: true)
            }
        }

        return true
    }
    
    private func createMapPin(from metadata: [String: String]) -> Bool {
        guard let latString = metadata["lat"],
              let lngString = metadata["lng"],
              let latitude = Double(latString),
              let longitude = Double(lngString) else {
            return false
        }
        
        // Validate coordinates are within Black Rock City bounds
        // BRC bounds approximately: 40.75°N to 40.82°N, -119.17°W to -119.25°W
        guard latitude >= 40.75 && latitude <= 40.82 &&
              longitude >= -119.25 && longitude <= -119.17 else {
            showInvalidCoordinatesError()
            return false
        }
        
        let title = metadata["title"] ?? "Custom Pin"

        // Save to PlayaDB
        let pin = UserMapPin(
            title: title,
            latitude: latitude,
            longitude: longitude,
            pinType: BRCMapPointType.userStar.pinTypeString
        )
        Task { @MainActor in
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            try? await playaDB.saveUserMapPin(pin)
        }

        // Show confirmation that pin was added
        Task { @MainActor in
            guard let tabController = self.tabController else { return }

            let message = "Custom pin \"\(title)\" has been added to your map."
            let alert = UIAlertController(title: "Pin Added", message: message, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "View on Map", style: .default) { _ in
                tabController.selectMapTab()
            })

            alert.addAction(UIAlertAction(title: "OK", style: .cancel))

            tabController.present(alert, animated: true)
        }

        return true
    }
    
    private func showObjectNotFound(uid: String, type: String, metadata: [String: String]) {
        let title = metadata["title"] ?? "Content"
        let message = "\(title) could not be found. It may not be available yet or may have been removed."
        
        let alert = UIAlertController(title: "Not Found", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        DispatchQueue.main.async {
            self.tabController?.present(alert, animated: true)
        }
    }
    
    private func showInvalidCoordinatesError() {
        let message = "The pin location is outside of Black Rock City."
        
        let alert = UIAlertController(title: "Invalid Location", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        DispatchQueue.main.async {
            self.tabController?.present(alert, animated: true)
        }
    }
    
    @objc private func dismissDetailSheet() {
        guard let tabController = tabController else { return }
        
        if let presentedVC = tabController.presentedViewController {
            presentedVC.dismiss(animated: true)
        }
    }
}

// MARK: - URL Generation

extension BRCDataObject {
    
    /// Universal link for this object, embargo-filtered.
    ///
    /// URL construction lives in `ShareURLBuilder` so the legacy and SwiftUI share paths
    /// emit identical links; this method only resolves the async host name and the embargo tier.
    @MainActor
    func generateShareURL() async -> URL? {
        var hostName: String?
        if let event = self as? BRCEventObject {
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            if let campId = event.hostedByCampUniqueID, !campId.isEmpty {
                hostName = try? await playaDB.fetchCamp(uid: campId)?.name
            } else if let artId = event.hostedByArtUniqueID, !artId.isEmpty {
                hostName = try? await playaDB.fetchArt(uid: artId)?.name
            }
        }

        guard let payload = ShareURLPayload.legacy(
            self,
            hostName: hostName,
            canShowLocation: BRCEmbargo.canShowLocation(for: self)
        ) else { return nil }

        return ShareURLBuilderFactory.shared.url(for: payload)
    }
}

extension BRCMapPoint {

    @objc func generateShareURL() -> URL? {
        let payload = ShareURLPayload(
            kind: .pin,
            title: title,
            coordinate: coordinate,
            pinType: Int(type.rawValue)
        )
        return ShareURLBuilderFactory.shared.url(for: payload)
    }
}