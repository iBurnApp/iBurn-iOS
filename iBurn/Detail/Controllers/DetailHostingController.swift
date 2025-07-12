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
    let viewModel: DetailViewModel
    let colors: BRCImageColors
    let coordinator: DetailActionCoordinator
    var indexPath: IndexPath?
    
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        coordinator: DetailActionCoordinator
    ) {
        // Determine colors based on data object type (similar to BRCDetailViewController)
        self.colors = BRCImageColors.colors(for: dataObject, fallback: Appearance.currentColors)
        self.coordinator = coordinator
        
        // Create ViewModel without side effects
        self.viewModel = DetailViewModel(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            coordinator: coordinator
        )
        
        // Create SwiftUI view
        let detailView = DetailView(viewModel: viewModel)
        super.init(rootView: detailView)
        
        // Configure UIKit properties
        self.title = dataObject.title
        self.hidesBottomBarWhenPushed = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure navigation bar appearance if needed
        setupNavigationBarAppearance()
    }
    
    private func setupNavigationBarAppearance() {
        // This can be customized based on existing app theming
        // For now, use default appearance
    }
}