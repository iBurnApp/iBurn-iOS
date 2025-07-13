//
//  DetailHostingController.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import SwiftUI

class DetailHostingController: UIHostingController<DetailView> {
    var viewModel: DetailViewModel!
    let colors: BRCImageColors
    var coordinator: DetailActionCoordinator!
    var indexPath: IndexPath?
    private let dataObject: BRCDataObject
    
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol
    ) {
        // Store dataObject for later use
        self.dataObject = dataObject
        
        // Determine colors based on data object type (similar to BRCDetailViewController)
        self.colors = BRCImageColors.colors(for: dataObject, fallback: Appearance.currentColors)
        
        // Create a temporary view with placeholder coordinator for super.init
        let tempCoordinator = DetailActionCoordinatorFactory.makeCoordinator(presenter: UIViewController(), navigator: nil)
        let tempViewModel = DetailViewModel(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            coordinator: tempCoordinator
        )
        let tempView = DetailView(viewModel: tempViewModel)
        
        super.init(rootView: tempView)
        
        // Now create the real coordinator with self as presenter
        self.coordinator = DetailActionCoordinatorFactory.makeCoordinator(
            presenter: self,
            navigator: nil  // Will be set in viewDidLoad
        )
        
        // Create ViewModel with proper coordinator
        self.viewModel = DetailViewModel(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            coordinator: coordinator
        )
        
        // Update the root view
        self.rootView = DetailView(viewModel: viewModel)
        
        // Configure UIKit properties
        self.title = dataObject.title
        self.hidesBottomBarWhenPushed = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Now we have navigationController - update the coordinator
        print("📱 DetailHostingController viewDidLoad - updating navigator")
        print("   self.navigationController: \(self.navigationController != nil ? "exists" : "nil")")
        coordinator.updateNavigator(self.navigationController)
        
        // Configure navigation bar appearance if needed
        setupNavigationBarAppearance()
    }
    
    private func setupNavigationBarAppearance() {
        // This can be customized based on existing app theming
        // For now, use default appearance
    }
}