//
//  DetailActionCoordinator.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import SafariServices
import EventKitUI

// MARK: - Protocol

/// Coordinator responsible for handling detail view actions
protocol DetailActionCoordinator: AnyObject {
    func handle(_ action: DetailAction)
    func updateNavigator(_ navigator: Navigable?)
    func updatePresenter(_ presenter: Presentable?)
}

// MARK: - Dependencies

/// Dependencies required for action coordination
struct DetailActionCoordinatorDependencies {
    var presenter: Presentable?
    var navigator: Navigable?
    let eventEditService: EventEditService
    
    init(presenter: Presentable? = nil, navigator: Navigable? = nil, eventEditService: EventEditService) {
        self.presenter = presenter
        self.navigator = navigator
        self.eventEditService = eventEditService
        
        // Debug logging for navigation issues
        if navigator == nil {
            print("⚠️ DetailActionCoordinator: Navigator is nil - navigation will not work")
        } else {
            print("✅ DetailActionCoordinator: Navigator available - \(type(of: navigator!))")
        }
        
        if presenter == nil {
            print("⚠️ DetailActionCoordinator: Presenter is nil - presentation will not work")
        } else {
            print("✅ DetailActionCoordinator: Presenter available - \(type(of: presenter!))")
        }
    }
}

// MARK: - Factory

/// Factory for creating DetailActionCoordinator instances
enum DetailActionCoordinatorFactory {
    /// Creates a coordinator for production use
    static func makeCoordinator(presenter: Presentable? = nil, navigator: Navigable? = nil) -> DetailActionCoordinator {
        let eventEditService = EventEditServiceFactory.makeService()
        
        print("🏗️ Creating DetailActionCoordinator:")
        print("   Presenter: \(presenter != nil ? String(describing: type(of: presenter!)) : "nil")")
        print("   Navigator: \(navigator != nil ? String(describing: type(of: navigator!)) : "nil")")
        
        let dependencies = DetailActionCoordinatorDependencies(
            presenter: presenter,
            navigator: navigator,
            eventEditService: eventEditService
        )
        return DetailActionCoordinatorImpl(dependencies: dependencies)
    }
    
    /// Creates a coordinator for testing with custom dependencies
    static func makeCoordinator(dependencies: DetailActionCoordinatorDependencies) -> DetailActionCoordinator {
        return DetailActionCoordinatorImpl(dependencies: dependencies)
    }
}

// MARK: - Private Implementation

private class DetailActionCoordinatorImpl: NSObject, DetailActionCoordinator, EKEventEditViewDelegate {
    private var dependencies: DetailActionCoordinatorDependencies
    
    init(dependencies: DetailActionCoordinatorDependencies) {
        self.dependencies = dependencies
    }
    
    func updateNavigator(_ navigator: Navigable?) {
        dependencies.navigator = navigator
        
        if navigator == nil {
            print("⚠️ Navigator updated to nil")
        } else {
            print("✅ Navigator updated: \(type(of: navigator!))")
        }
    }
    
    func updatePresenter(_ presenter: Presentable?) {
        dependencies.presenter = presenter
        
        if presenter == nil {
            print("⚠️ Presenter updated to nil")
        } else {
            print("✅ Presenter updated: \(type(of: presenter!))")
        }
    }
    
    func handle(_ action: DetailAction) {
        switch action {
        case .openEmail(let email):
            WebViewHelper.openEmail(to: email)
            
        case .openURL(let url):
            // Need to cast for WebViewHelper, but that's OK - it requires UIViewController specifically
            if let viewController = dependencies.presenter as? UIViewController {
                WebViewHelper.presentWebView(url: url, from: viewController)
            }
            
        case .showEventEditor(let event):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot show event editor: No presenter available")
                return
            }
            let eventEditController = dependencies.eventEditService.createEventEditController(for: event)
            eventEditController.editViewDelegate = self
            presenter.present(eventEditController, animated: true, completion: nil)
            
        case .shareCoordinates(let coordinate):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot share coordinates: No presenter available")
                return
            }
            let activityViewController = createShareController(for: coordinate)
            presenter.present(activityViewController, animated: true, completion: nil)
            
            
        case .showMap(let dataObject):
            print("🗺️ Attempting to show map for object: \(dataObject.title)")
            
            guard let navigator = dependencies.navigator else {
                print("❌ Map navigation FAILED: Navigator is nil")
                return
            }
            
            // Get metadata for the object
            var metadata: BRCObjectMetadata?
            BRCDatabaseManager.shared.uiConnection.read { transaction in
                metadata = dataObject.metadata(with: transaction)
            }
            
            // Create MapDetailViewController following old BRCDetailViewController pattern
            let mapViewController = MapDetailViewController(dataObject: dataObject, metadata: metadata ?? BRCObjectMetadata())
            mapViewController.title = "Map - \(dataObject.title)"
            
            print("🚀 Pushing MapDetailViewController")
            navigator.pushViewController(mapViewController, animated: true)
            
        case .navigateToObject(let object):
            print("🧭 Attempting navigation to object: \(object.title)")
            
            guard let navigator = dependencies.navigator else {
                print("❌ Navigation FAILED: Navigator is nil")
                print("   Presenter: \(type(of: dependencies.presenter))")
                return
            }
            
            print("✅ Navigator found: \(type(of: navigator))")
            
            let detailVC = DetailViewControllerFactory.createDetailViewController(for: object)
            
            print("🚀 Pushing view controller: \(type(of: detailVC))")
            navigator.pushViewController(detailVC, animated: true)
            
        case .showEventsList(let events, let hostName):
            print("🎪 Attempting to show \(events.count) events for \(hostName)")
            
            guard let navigator = dependencies.navigator else {
                print("❌ Navigation FAILED: Navigator is nil")
                return
            }
            
            guard let firstEvent = events.first else {
                print("❌ No events provided for \(hostName)")
                return
            }
            
            var relatedObject: BRCDataObject?
            
            // Use database transaction to get the host object
            BRCDatabaseManager.shared.uiConnection.read { transaction in
                relatedObject = firstEvent.host(with: transaction)
            }
            
            guard let host = relatedObject else {
                print("❌ Could not find host object for events")
                return
            }
            
            print("✅ Found host object: \(host.title)")
            
            // Create and push HostedEventsViewController (matching old BRCDetailViewController pattern)
            let eventsVC = HostedEventsViewController(
                style: .grouped,
                extensionName: BRCDatabaseManager.shared.relationships,
                relatedObject: host
            )
            eventsVC.title = "Events - \(hostName)"
            
            print("🚀 Pushing HostedEventsViewController")
            navigator.pushViewController(eventsVC, animated: true)
            
        case .playAudio(_):
            // Audio is handled directly by AudioService in ViewModel
            break
            
        case .pauseAudio:
            // Audio is handled directly by AudioService in ViewModel
            break
            
        case .editNotes(let current, let completion):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot edit notes: No presenter available")
                return
            }
            // Present notes editor
            let alertController = createNotesEditor(currentNotes: current, completion: completion)
            presenter.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - View Controller Creation
    
    
    private func createShareController(for coordinate: CLLocationCoordinate2D) -> UIViewController {
        let locationString = String(format: "Location: %.6f, %.6f", coordinate.latitude, coordinate.longitude)
        let activityItems: [Any] = [locationString]
        
        return UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }
    
    
    private func createNotesEditor(currentNotes: String, completion: @escaping (String) -> Void) -> UIAlertController {
        let alertController = UIAlertController(
            title: "Edit Notes",
            message: nil,
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.text = currentNotes
            textField.placeholder = "Add your notes..."
            textField.autocapitalizationType = .sentences
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let textField = alertController.textFields?.first {
                completion(textField.text ?? "")
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        return alertController
    }
}


// MARK: - EKEventEditViewDelegate

extension DetailActionCoordinatorImpl {
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        // Dismiss the event edit controller
        dependencies.presenter?.dismiss(animated: true, completion: nil)
        
        // Log the action for debugging
        switch action {
        case .cancelled:
            print("📅 Event creation cancelled")
        case .canceled:
            print("📅 Event creation canceled")
        case .saved:
            print("📅 Event saved to calendar")
        case .deleted:
            print("📅 Event deleted")
        @unknown default:
            print("📅 Unknown event edit action: \(action.rawValue)")
        }
    }
}
