//
//  DetailViewControllerFactory+Preference.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit

extension DetailViewControllerFactory {
    
    /// Creates a detail view controller using the preference system to determine implementation
    /// - Parameters:
    ///   - dataObject: The data object to display
    ///   - coordinator: The action coordinator
    /// - Returns: Either the new SwiftUI or legacy UIKit implementation based on preference
    static func createDetailViewController(
        for dataObject: BRCDataObject,
        coordinator: DetailActionCoordinator
    ) -> UIViewController {
        
        #if DEBUG
        // Check feature flag preference
        let service = PreferenceServiceFactory.shared
        if service.getValue(Preferences.FeatureFlags.useSwiftUIDetailView) {
            // Use new SwiftUI implementation
            return create(with: dataObject, coordinator: coordinator)
        }
        #endif
        
        // Use legacy UIKit implementation
        return BRCDetailViewController(dataObject: dataObject)
    }
}