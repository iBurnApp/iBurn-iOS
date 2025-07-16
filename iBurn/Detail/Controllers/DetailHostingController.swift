//
//  DetailHostingController.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import SwiftUI

// MARK: - Safe Navigation Extension

extension UIViewController {
    /// Safely finds a navigation controller by traversing the parent hierarchy
    /// Based on the pattern used in ListCoordinator.swift
    var safeNavigationController: UINavigationController? {
        // Direct access first
        if let nav = navigationController {
            return nav
        }
        
        // Check presenting view controller (for modals)
        if let nav = presentingViewController?.navigationController {
            return nav
        }
        
        // Traverse parent hierarchy (for UIPageViewController children)
        var current = parent
        while let parent = current {
            if let nav = parent.navigationController {
                return nav
            }
            current = parent.parent
        }
        
        return nil
    }
}

class DetailHostingController: UIHostingController<DetailView>, DynamicViewController {
    let viewModel: DetailViewModel
    let colors: BRCImageColors
    let coordinator: DetailActionCoordinator
    var indexPath: IndexPath?
    private let dataObject: BRCDataObject
    
    // MARK: - DynamicViewController
    var eventHandler: DynamicViewControllerEventHandler?
    
    init(
        viewModel: DetailViewModel,
        coordinator: DetailActionCoordinator,
        colors: BRCImageColors,
        dataObject: BRCDataObject
    ) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.colors = colors
        self.dataObject = dataObject
        
        super.init(rootView: DetailView(viewModel: viewModel))
        
        self.title = dataObject.title
        self.hidesBottomBarWhenPushed = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure navigation bar appearance
        setupNavigationBarAppearance()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Notify event handler about layout changes that might affect navigation items
        notifyEventHandler(.viewWillLayoutSubviews)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update navigator when view hierarchy is fully established
        let navController = safeNavigationController
        print("📱 DetailHostingController viewDidAppear - updating coordinator")
        print("   safeNavigationController: \(navController != nil ? "exists" : "nil")")
        if let nav = navController {
            print("   Found navigation controller: \(type(of: nav))")
        } else {
            print("   Parent hierarchy: self -> \(parent?.description ?? "nil") -> \(parent?.parent?.description ?? "nil")")
        }
        
        // Ensure coordinator has correct presenter and navigator
        coordinator.updatePresenter(self)
        coordinator.updateNavigator(navController)
        
        // Notify event handler that view appeared (navigation items may need updating)
        notifyEventHandler(.viewDidAppear)
    }
    
    private func setupNavigationBarAppearance() {
        // This can be customized based on existing app theming
        // For now, use default appearance
    }
}