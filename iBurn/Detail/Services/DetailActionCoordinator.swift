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
import SwiftUI
import PlayaDB

// MARK: - Protocol

/// Coordinator responsible for handling detail view actions
@MainActor
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
    
    init(presenter: Presentable? = nil, navigator: Navigable? = nil) {
        self.presenter = presenter
        self.navigator = navigator
        
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
@MainActor
enum DetailActionCoordinatorFactory {
    /// Creates a coordinator for production use
    static func makeCoordinator(presenter: Presentable? = nil, navigator: Navigable? = nil) -> DetailActionCoordinator {
        print("🏗️ Creating DetailActionCoordinator:")
        print("   Presenter: \(presenter != nil ? String(describing: type(of: presenter!)) : "nil")")
        print("   Navigator: \(navigator != nil ? String(describing: type(of: navigator!)) : "nil")")
        
        let dependencies = DetailActionCoordinatorDependencies(
            presenter: presenter,
            navigator: navigator
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
            
            // Get the host object for location formatting
            var host: BRCDataObject?
            BRCDatabaseManager.shared.uiConnection.read { transaction in
                host = event.host(with: transaction)
            }
            
            let eventEditController = EventEditControllerFactory.createEventEditController(for: event, host: host)
            eventEditController.editViewDelegate = self
            presenter.present(eventEditController, animated: true, completion: nil)
            
        case .shareCoordinates(let coordinate):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot share coordinates: No presenter available")
                return
            }
            let activityViewController = createShareController(for: coordinate)
            
            // iPad popover support
            if let popover = activityViewController.popoverPresentationController {
                if let viewController = presenter as? UIViewController {
                    popover.sourceView = viewController.view
                    // Position the popover at a reasonable location
                    popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: 100, width: 0, height: 0)
                }
            }
            
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
            guard let navigator = dependencies.navigator else { return }
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            Task { @MainActor in
                let detailVC = await DetailViewControllerFactory.createDetailViewController(for: object, playaDB: playaDB)
                navigator.pushViewController(detailVC, animated: true)
            }
            
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
            
        case .showNextEvent(let nextEvent):
            print("⏭️ Attempting to show next event: \(nextEvent.title)")
            
            guard let _ = dependencies.navigator else {
                print("❌ Navigation FAILED: Navigator is nil")
                return
            }
            
            // Navigate to the next event's detail view
            self.handle(.navigateToObject(nextEvent))

        case .showMapAnnotation(let annotation, let title):
            guard let navigator = dependencies.navigator else {
                print("❌ Cannot show map: Navigator is nil")
                return
            }
            let dataSource = StaticAnnotationDataSource(annotation: annotation)
            let mapVC = MapListViewController(dataSource: dataSource)
            mapVC.title = title
            navigator.pushViewController(mapVC, animated: true)
            
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
            
        case .share(let activityItems):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot share: No presenter available")
                return
            }
            
            let activityController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            // iPad support
            if let popover = activityController.popoverPresentationController {
                // Try to get the share button from the navigation bar
                if let navController = presenter as? UINavigationController,
                   let topVC = navController.topViewController {
                    if let shareButton = topVC.navigationItem.rightBarButtonItems?.first {
                        popover.barButtonItem = shareButton
                    } else {
                        popover.sourceView = topVC.view
                        popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: 100, width: 0, height: 0)
                    }
                } else if let viewController = presenter as? UIViewController {
                    popover.sourceView = viewController.view
                    popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: 100, width: 0, height: 0)
                }
            }
            
            presenter.present(activityController, animated: true, completion: nil)
            
        case .showShareScreen(let dataObject):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot show share screen: No presenter available")
                return
            }

            let shareViewController = ShareQRCodeHostingController(dataObject: dataObject)
            presenter.present(shareViewController, animated: true, completion: nil)

        case .navigateToViewController(let viewController):
            guard let navigator = dependencies.navigator else {
                print("❌ Navigation FAILED: Navigator is nil")
                return
            }
            navigator.pushViewController(viewController, animated: true)
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
