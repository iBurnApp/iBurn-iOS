//
//  TimeShiftViewController.swift
//  iBurn
//
//  Created by Claude Code on 8/3/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import SwiftUI
import CoreLocation

public class TimeShiftViewController: UIHostingController<TimeShiftView> {
    // MARK: - Properties
    let viewModel: TimeShiftViewModel
    
    // MARK: - Initialization
    public init(viewModel: TimeShiftViewModel) {
        self.viewModel = viewModel
        
        // Create the SwiftUI view with the injected ViewModel
        let timeShiftView = TimeShiftView(viewModel: viewModel)
        
        super.init(rootView: timeShiftView)
        
        // Configure presentation
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.largestUndimmedDetentIdentifier = .medium
        }
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}