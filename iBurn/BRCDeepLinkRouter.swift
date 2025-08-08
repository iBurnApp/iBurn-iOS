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

enum DeepLinkObjectType: String {
    case art = "art"
    case camp = "camp"
    case event = "event"
    case pin = "pin"
}

@objc class BRCDeepLinkRouter: NSObject {
    
    @objc static let shared = BRCDeepLinkRouter()
    
    private weak var tabController: TabController?
    
    @objc func configure(with tabController: TabController) {
        self.tabController = tabController
    }
    
    // MARK: - URL Handling
    
    @objc func canHandle(_ url: URL) -> Bool {
        if url.scheme == "iburn" {
            return true
        }
        if url.host == "iburnapp.com" || url.host == "www.iburnapp.com" {
            return true
        }
        return false
    }
    
    @objc func handle(_ url: URL) -> Bool {
        guard canHandle(url) else { return false }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let firstComponent = pathComponents.first else { return false }
        
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let metadata = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        
        switch firstComponent {
        case "art", "camp", "event":
            // UID is now a query parameter
            guard let uid = metadata["uid"] else { return false }
            return navigateToObject(uid: uid, type: firstComponent, metadata: metadata)
            
        case "pin":
            return createMapPin(from: metadata)
            
        default:
            return false
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToObject(uid: String, type: String, metadata: [String: String]) -> Bool {
        guard let tabController = tabController else { return false }
        
        // Find object in database
        let connection = BRCDatabaseManager.shared.uiConnection
        var object: BRCDataObject?
        
        connection?.read { transaction in
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
            // Object not found - show error or search
            showObjectNotFound(uid: uid, type: type, metadata: metadata)
            return false
        }
        
        // Navigate to object
        DispatchQueue.main.async {
            // Switch to map tab (index 0)
            tabController.selectedIndex = 0
            
            // Push detail view
            let detailVC = DetailViewControllerFactory.viewController(for: dataObject)
            if let navController = tabController.selectedViewController as? UINavigationController {
                navController.pushViewController(detailVC, animated: true)
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
        let description = metadata["desc"]
        let address = metadata["addr"]
        let color = metadata["color"] ?? "red"
        
        // Create and save custom pin
        let pin = BRCMapPin()
        pin.uniqueID = UUID().uuidString
        pin.title = title
        pin.detailDescription = description
        pin.playaLocation = address
        pin.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        pin.color = color
        pin.createdDate = Date()
        
        // Save to database
        BRCDatabaseManager.shared.readWriteConnection?.asyncReadWrite { transaction in
            transaction.setObject(pin, forKey: pin.yapKey, inCollection: BRCMapPin.yapCollection)
        }
        
        // Navigate to map and show pin
        DispatchQueue.main.async {
            guard let tabController = self.tabController else { return }
            
            // Switch to map tab
            tabController.selectedIndex = 0
            
            // Center map on pin
            if let navController = tabController.selectedViewController as? UINavigationController,
               let mapVC = navController.viewControllers.first as? MainMapViewController {
                mapVC.centerMapOn(dataObject: pin)
                // Select annotation after a short delay to ensure it's been added
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    mapVC.selectAnnotation(for: pin)
                }
            }
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
        
        if let location = location {
            queryItems.append(URLQueryItem(name: "lat", value: String(format: "%.6f", location.coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: String(format: "%.6f", location.coordinate.longitude)))
        }
        
        if let playaLocation = playaLocation, !playaLocation.isEmpty {
            queryItems.append(URLQueryItem(name: "addr", value: playaLocation))
        }
        
        if let description = detailDescription, !description.isEmpty {
            let truncated = String(description.prefix(100))
            queryItems.append(URLQueryItem(name: "desc", value: truncated))
        }
        
        // Event-specific parameters
        if let event = self as? BRCEventObject {
            if let startDate = event.startDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
                queryItems.append(URLQueryItem(name: "start", value: formatter.string(from: startDate)))
            }
            if let endDate = event.endDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
                queryItems.append(URLQueryItem(name: "end", value: formatter.string(from: endDate)))
            }
            
            // Add host information
            BRCDatabaseManager.shared.uiConnection?.read { transaction in
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
        let yearSettings = YearSettings.current
        queryItems.append(URLQueryItem(name: "year", value: String(yearSettings.year)))
        
        components.queryItems = queryItems
        
        return components.url
    }
}

extension BRCMapPin {
    
    @objc func generateShareURL() -> URL? {
        var components = URLComponents(string: "https://iburnapp.com")!
        components.path = "/pin"
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        
        queryItems.append(URLQueryItem(name: "lat", value: String(format: "%.6f", coordinate.latitude)))
        queryItems.append(URLQueryItem(name: "lng", value: String(format: "%.6f", coordinate.longitude)))
        queryItems.append(URLQueryItem(name: "title", value: title))
        
        if let playaLocation = playaLocation, !playaLocation.isEmpty {
            queryItems.append(URLQueryItem(name: "addr", value: playaLocation))
        }
        
        if let description = detailDescription, !description.isEmpty {
            let truncated = String(description.prefix(100))
            queryItems.append(URLQueryItem(name: "desc", value: truncated))
        }
        
        queryItems.append(URLQueryItem(name: "color", value: color))
        
        // Add year
        let yearSettings = YearSettings.current
        queryItems.append(URLQueryItem(name: "year", value: String(yearSettings.year)))
        
        components.queryItems = queryItems
        
        return components.url
    }
}