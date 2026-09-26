//
//  DetailActionCoordinator.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import SafariServices
import CoreLocation
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

private class DetailActionCoordinatorImpl: NSObject, DetailActionCoordinator {
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
            
            
        case .showMapAnnotation(let annotation, let title):
            guard let navigator = dependencies.navigator else {
                print("❌ Cannot show map: Navigator is nil")
                return
            }
            let dataSource = StaticAnnotationDataSource(annotation: annotation)
            let mapVC = MapListViewController(dataSource: dataSource)
            mapVC.title = title
            navigator.pushViewController(mapVC, animated: true)
            
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
            
        case .showShareURLScreen(let title, let locationText, let url, let themeColors):
            guard let presenter = dependencies.presenter else {
                print("❌ Cannot show share screen: No presenter available")
                return
            }

            let shareViewController = ShareQRCodeHostingController(
                title: title,
                locationText: locationText,
                shareURL: url,
                themeColors: themeColors
            )
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
