//
//  BRCDeepLinkRouter.swift
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import UIKit
import CoreLocation
import YapDatabase
import CocoaLumberjack

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
        
        // Find object in database
        let connection = BRCDatabaseManager.shared.uiConnection
        var object: BRCDataObject?
        
        connection.read { transaction in
            switch type {
            case "art":
                object = transaction.object(forKey: uid, inCollection: BRCArtObject.yapCollection) as? BRCArtObject
            case "camp":
                object = transaction.object(forKey: uid, inCollection: BRCCampObject.yapCollection) as? BRCCampObject
            case "event":
                object = transaction.object(forKey: uid, inCollection: BRCEventObject.yapCollection) as? BRCEventObject
            default:
                break
            }
        }
        
        guard let dataObject = object else {
            DDLogWarn("Object not found for UID: \(uid) type: \(type)")
            // Object not found - show error or search
            showObjectNotFound(uid: uid, type: type, metadata: metadata)
            return false
        }
        
        DDLogInfo("Found object: \(dataObject.title) for UID: \(uid)")
        
        // Navigate to object - present as sheet over current interface
        DispatchQueue.main.async {
            let detailVC = DetailViewControllerFactory.createDetailViewController(for: dataObject)
            
            // Wrap in navigation controller for sheet presentation
            let navController = UINavigationController(rootViewController: detailVC)
            navController.modalPresentationStyle = .pageSheet
            
            // Add close button to navigation bar
            detailVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(self.dismissDetailSheet)
            )
            
            // Present over current interface
            if let presentedVC = tabController.presentedViewController {
                // If something is already presented, present over it
                presentedVC.present(navController, animated: true)
            } else {
                // Present over tab controller
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
        let _ = metadata["desc"]
        let _ = metadata["addr"]
        let _ = metadata["color"] ?? "red"
        
        // Create and save custom pin as BRCUserMapPoint
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let pin = BRCUserMapPoint(title: title, coordinate: coordinate, type: .userStar)
        // BRCUserMapPoint uses yapKey generated from creationDate
        
        // Save to database
        BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
            transaction.setObject(pin, forKey: pin.yapKey, inCollection: pin.yapCollection)
        }
        
        // Show confirmation that pin was added
        DispatchQueue.main.async {
            guard let tabController = self.tabController else { return }
            
            let message = "Custom pin \"\(title)\" has been added to your map."
            let alert = UIAlertController(title: "Pin Added", message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "View on Map", style: .default) { _ in
                // Switch to map tab to show the pin
                tabController.selectedIndex = 0
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
    
    @objc func generateShareURL() -> URL? {
        var components = URLComponents(string: "https://iburnapp.com")!
        
        // Set path based on object type
        if self is BRCArtObject {
            components.path = "/art/"
        } else if self is BRCCampObject {
            components.path = "/camp/"
        } else if self is BRCEventObject {
            components.path = "/event/"
        } else {
            return nil
        }
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        
        // UID as query parameter
        queryItems.append(URLQueryItem(name: "uid", value: uniqueID))
        
        // Universal parameters
        queryItems.append(URLQueryItem(name: "title", value: title))
        
        // Only include location data if embargo allows it
        if BRCEmbargo.canShowLocation(for: self) {
            if let location = location {
                queryItems.append(URLQueryItem(name: "lat", value: String(format: "%.6f", location.coordinate.latitude)))
                queryItems.append(URLQueryItem(name: "lng", value: String(format: "%.6f", location.coordinate.longitude)))
            }
            
            if let playaLocation = playaLocation, !playaLocation.isEmpty {
                queryItems.append(URLQueryItem(name: "addr", value: playaLocation))
            }
        }
        
        if let description = detailDescription, !description.isEmpty {
            let truncated = String(description.prefix(100))
            queryItems.append(URLQueryItem(name: "desc", value: truncated))
        }
        
        // Event-specific parameters
        if let event = self as? BRCEventObject {
            let startDate = event.startDate
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
            queryItems.append(URLQueryItem(name: "start", value: formatter.string(from: startDate)))
            
            let endDate = event.endDate
            queryItems.append(URLQueryItem(name: "end", value: formatter.string(from: endDate)))
            
            // Add host information
            BRCDatabaseManager.shared.uiConnection.read { transaction in
                if let campHost = event.hostedByCamp(with: transaction) {
                    queryItems.append(URLQueryItem(name: "host", value: campHost.title))
                    queryItems.append(URLQueryItem(name: "host_id", value: campHost.uniqueID))
                    queryItems.append(URLQueryItem(name: "host_type", value: "camp"))
                } else if let artHost = event.hostedByArt(with: transaction) {
                    queryItems.append(URLQueryItem(name: "host", value: artHost.title))
                    queryItems.append(URLQueryItem(name: "host_id", value: artHost.uniqueID))
                    queryItems.append(URLQueryItem(name: "host_type", value: "art"))
                }
            }
            
            if event.isAllDay {
                queryItems.append(URLQueryItem(name: "all_day", value: "true"))
            }
        }
        
        // Add year
        queryItems.append(URLQueryItem(name: "year", value: YearSettings.playaYear))
        
        components.queryItems = queryItems
        
        return components.url
    }
}

extension BRCMapPoint {
    
    @objc func generateShareURL() -> URL? {
        var components = URLComponents(string: "https://iburnapp.com")!
        components.path = "/pin"
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        
        queryItems.append(URLQueryItem(name: "lat", value: String(format: "%.6f", coordinate.latitude)))
        queryItems.append(URLQueryItem(name: "lng", value: String(format: "%.6f", coordinate.longitude)))
        
        if let title = title {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        
        // Map point type
        queryItems.append(URLQueryItem(name: "type", value: String(type.rawValue)))
        
        // Add year
        queryItems.append(URLQueryItem(name: "year", value: YearSettings.playaYear))
        
        components.queryItems = queryItems
        
        return components.url
    }
}