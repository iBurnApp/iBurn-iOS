//
//  CustomizeTabsHostingController.swift
//  iBurn
//
//  Created by Claude Code on 8/8/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import UIKit
import SwiftUI

/// UIKit hosting controller for the tab bar customization screen, pushed from More.
class CustomizeTabsHostingController: UIHostingController<CustomizeTabsView> {

    init() {
        super.init(rootView: CustomizeTabsView())
        title = "Customize Tabs"
        updateColors(animated: false)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateColors(animated: animated)
    }

    private func updateColors(animated: Bool) {
        refreshNavigationBarColors(animated)
        view.backgroundColor = Appearance.currentColors.backgroundColor
    }
}
