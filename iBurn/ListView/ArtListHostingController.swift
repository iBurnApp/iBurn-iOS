//
//  ArtListHostingController.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

/// UIKit hosting controller that wraps the SwiftUI ArtListView
///
/// This controller acts as a bridge between the legacy UIKit-based navigation
/// and the new SwiftUI list implementation. It's initialized with dependencies
/// from the DependencyContainer and presents the ArtListView.
///
/// Usage:
/// ```swift
/// let controller = try ArtListHostingController(dependencies: appDelegate.dependencies)
/// navigationController.pushViewController(controller, animated: true)
/// ```
@MainActor
class ArtListHostingController: UIHostingController<ArtListView> {

    /// Initialize the hosting controller with dependencies
    /// - Parameter dependencies: The dependency container providing PlayaDB and other services
    /// - Throws: Errors from creating the view model
    init(dependencies: DependencyContainer) {
        // Create the view model using the dependency container's factory method
        let viewModel = dependencies.makeArtListViewModel()

        // Create the SwiftUI view
        let artListView = ArtListView(viewModel: viewModel)

        // Initialize the hosting controller
        super.init(rootView: artListView)

        // Configure the view controller
        self.title = "Art"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
