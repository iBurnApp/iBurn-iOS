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
}

// MARK: - Dependencies

/// Dependencies required for action coordination
struct DetailActionCoordinatorDependencies {
    let presenter: Presentable
    var navigator: Navigable?
    let eventEditService: EventEditService
    
    init(presenter: Presentable, navigator: Navigable?, eventEditService: EventEditService) {
        self.presenter = presenter
        self.navigator = navigator
        self.eventEditService = eventEditService
        
        // Debug logging for navigation issues
        if navigator == nil {
            print("⚠️ DetailActionCoordinator: Navigator is nil - navigation will not work")
            print("   Presenter: \(type(of: presenter))")
        } else {
            print("✅ DetailActionCoordinator: Navigator available - \(type(of: navigator!))")
        }
    }
}

// MARK: - Factory

/// Factory for creating DetailActionCoordinator instances
enum DetailActionCoordinatorFactory {
    /// Creates a coordinator for production use
    static func makeCoordinator(presenter: Presentable, navigator: Navigable?) -> DetailActionCoordinator {
        let eventEditService = EventEditServiceFactory.makeService()
        
        print("🏗️ Creating DetailActionCoordinator:")
        print("   Presenter: \(type(of: presenter))")
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

private class DetailActionCoordinatorImpl: DetailActionCoordinator {
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
            let eventEditController = dependencies.eventEditService.createEventEditController(for: event)
            dependencies.presenter.present(eventEditController, animated: true, completion: nil)
            
        case .shareCoordinates(let coordinate):
            let activityViewController = createShareController(for: coordinate)
            dependencies.presenter.present(activityViewController, animated: true, completion: nil)
            
        case .showImageViewer(let image):
            let imageViewController = createImageViewer(for: image)
            dependencies.presenter.present(imageViewController, animated: true, completion: nil)
            
        case .showMap(let dataObject):
            // This would require navigation to map view with object selected
            // For now, just log
            print("Show map for object: \(dataObject.yapKey)")
            
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
            // This would show a list of events
            print("Show \(events.count) events for \(hostName)")
            
        case .playAudio(_):
            // Audio is handled directly by AudioService in ViewModel
            break
            
        case .pauseAudio:
            // Audio is handled directly by AudioService in ViewModel
            break
            
        case .editNotes(let current, let completion):
            // Present notes editor
            let alertController = createNotesEditor(currentNotes: current, completion: completion)
            dependencies.presenter.present(alertController, animated: true, completion: nil)
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
    
    private func createImageViewer(for image: UIImage) -> UIViewController {
        let imageViewController = ImageViewerViewController(image: image, presenter: dependencies.presenter)
        imageViewController.modalPresentationStyle = .fullScreen
        imageViewController.modalTransitionStyle = .crossDissolve
        return imageViewController
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

// MARK: - Image Viewer Controller

private class ImageViewerViewController: UIViewController {
    private let image: UIImage
    private weak var presenter: Presentable?
    
    init(image: UIImage, presenter: Presentable?) {
        self.image = image
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.isUserInteractionEnabled = true
        
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissViewer))
        imageView.addGestureRecognizer(tapGesture)
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(dismissViewer), for: .touchUpInside)
        
        view.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func dismissViewer() {
        presenter?.dismiss(animated: true, completion: nil)
    }
}