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
    
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        actionsHandler: @escaping (DetailAction) -> Void
    ) {
        // Create ViewModel without side effects
        self.viewModel = DetailViewModel(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            actionsHandler: actionsHandler
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