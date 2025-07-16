//
//  DetailPageViewController.swift
//  iBurn
//
//  Created by Claude Code on 7/13/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

/// Custom UIPageViewController that properly handles navigation item forwarding
/// for both SwiftUI (DetailHostingController) and UIKit (BRCDetailViewController) children
class DetailPageViewController: UIPageViewController {
    
    // MARK: - Properties
    
    /// Track whether we need to update navigation items
    private var needsNavigationUpdate = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupChildObservation()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Update navigation items if needed
        if needsNavigationUpdate {
            updateNavigationItemsFromCurrentChild()
            needsNavigationUpdate = false
        }
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController]?, direction: UIPageViewController.NavigationDirection, animated: Bool, completion: ((Bool) -> Void)?) {
        super.setViewControllers(viewControllers, direction: direction, animated: animated) { [weak self] completed in
            if completed {
                self?.setupEventHandlerForCurrentChild()
                self?.updateNavigationItemsFromCurrentChild()
            }
            completion?(completed)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupChildObservation() {
        setupEventHandlerForCurrentChild()
        updateNavigationItemsFromCurrentChild()
    }
    
    private func setupEventHandlerForCurrentChild() {
        guard let currentChild = viewControllers?.first else { return }
        
        // Set up event handler for dynamic view controllers
        if let dynamicVC = currentChild as? DynamicViewController {
            dynamicVC.eventHandler = self
            print("📱 DetailPageViewController: Set up event handler for \(type(of: currentChild))")
        }
    }
    
    private func updateNavigationItemsFromCurrentChild() {
        guard let currentChild = viewControllers?.first else { return }
        
        print("📱 DetailPageViewController: Updating navigation items from \(type(of: currentChild))")
        
        // Generic navigation item forwarding - works with any UIViewController
        copyParameters(from: currentChild)
    }
    
}

// MARK: - DynamicViewControllerEventHandler

extension DetailPageViewController: DynamicViewControllerEventHandler {
    func viewControllerDidTriggerEvent(_ event: ViewControllerEvent, sender: UIViewController) {
        print("📱 DetailPageViewController: Received event \(event) from \(type(of: sender))")
        
        switch event {
        case .viewWillLayoutSubviews, .navigationItemDidChange, .toolbarDidChange:
            // Mark that we need to update navigation items on next layout
            needsNavigationUpdate = true
            
        case .viewDidAppear:
            // Immediate update for view appearance - generic copying
            copyParameters(from: sender)
            
        case .viewWillDisappear:
            // Could handle cleanup if needed
            break
        }
    }
}
