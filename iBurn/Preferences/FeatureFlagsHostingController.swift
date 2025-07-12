//
//  FeatureFlagsHostingController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

#if DEBUG

import UIKit
import SwiftUI

/// UIKit hosting controller for the feature flags debug view
class FeatureFlagsHostingController: UIHostingController<FeatureFlagsView> {
    
    init() {
        super.init(rootView: FeatureFlagsView())
        
        // Apply current theme
        updateColors(animated: false)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update colors when view appears
        updateColors(animated: animated)
    }
    
    private func updateColors(animated: Bool) {
        // Apply current app theme to navigation bar
        refreshNavigationBarColors(animated)
        
        // Set background color
        view.backgroundColor = Appearance.currentColors.backgroundColor
    }
}

#endif