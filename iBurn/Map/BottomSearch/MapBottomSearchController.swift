//
//  MapBottomSearchController.swift
//  iBurn
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Drives the bottom-anchored search prototype. Two states:
//
//  - Resting: a `MapSearchAccessoryView` pill installed as the tab bar's
//    `UITabAccessory`, so it sits on the system glass above the tab bar.
//  - Active: the accessory is pulled, the existing SwiftUI results controller is
//    added as a child layered over the map, and a real editable field docks to the
//    keyboard. The results view stays transparent until there's something to show.
//
//  The results controller is added as a child of the *map* view controller on
//  purpose: `GlobalSearchHostingController` resolves its push target through
//  `parent?.navigationController`, so parenting it here keeps result taps pushing
//  onto the map's own navigation stack.
//

import UIKit

@MainActor
final class MapBottomSearchController {

    private unowned let host: UIViewController
    private let resultsController: GlobalSearchHostingController

    let accessoryView = MapSearchAccessoryView()
    private lazy var inputBar: MapSearchInputBar = {
        let bar = MapSearchInputBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.onTextChange = { [weak self] text in
            self?.resultsController.viewModel.searchText = text
        }
        bar.onCancel = { [weak self] in self?.deactivate() }
        bar.onSubmit = { [weak self] in self?.inputBar.textField.resignFirstResponder() }
        return bar
    }()

    private(set) var isActive = false

    init(host: UIViewController, resultsController: GlobalSearchHostingController) {
        self.host = host
        self.resultsController = resultsController
        accessoryView.onTap = { [weak self] in self?.activate() }
    }

    // MARK: - Accessory installation

    /// Installs the resting pill. iOS 26 only — callers gate on `MapSearchLayout`.
    func installAccessory() {
        guard #available(iOS 26.0, *), !isActive else { return }
        guard let tabBarController = host.tabBarController else { return }
        accessoryView.applyTheme()
        tabBarController.setBottomAccessory(UITabAccessory(contentView: accessoryView), animated: true)
    }

    func removeAccessory(animated: Bool = true) {
        guard #available(iOS 26.0, *) else { return }
        host.tabBarController?.setBottomAccessory(nil, animated: animated)
    }

    // MARK: - Activation

    func activate() {
        guard !isActive else { return }
        isActive = true

        // Pull the pill so the editable field is the only search affordance on screen.
        removeAccessory()

        host.addChild(resultsController)
        // Search rides over the map instead of covering it: the results view paints its
        // own material once there's a list, and stays clear while it's empty.
        resultsController.isOverlay = true
        // The input bar is already pinned to `keyboardLayoutGuide`, so the results view
        // sits entirely above the keyboard. Leaving SwiftUI's own keyboard avoidance on
        // would inset the list by the keyboard height a second time, collapsing it to a
        // sliver that clips mid-row.
        resultsController.safeAreaRegions = .container
        let results = resultsController.view!
        results.translatesAutoresizingMaskIntoConstraints = false
        results.backgroundColor = .clear
        host.view.addSubview(results)

        host.view.addSubview(inputBar)
        inputBar.applyTheme()

        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            // Rides the keyboard; rests on the safe-area bottom when it's down.
            inputBar.bottomAnchor.constraint(equalTo: host.view.keyboardLayoutGuide.topAnchor),

            results.topAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.topAnchor),
            results.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            results.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            results.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
        ])

        resultsController.didMove(toParent: host)

        results.alpha = 0
        inputBar.alpha = 0
        host.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25) {
            results.alpha = 1
            self.inputBar.alpha = 1
        }

        inputBar.textField.becomeFirstResponder()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false

        inputBar.textField.resignFirstResponder()
        // The results controller is shared across activations, so a scope chosen for the
        // last search would otherwise silently narrow the next one.
        resultsController.viewModel.searchText = ""
        resultsController.viewModel.scope = .all

        let results = resultsController.view

        resultsController.willMove(toParent: nil)

        UIView.animate(withDuration: 0.2) {
            results?.alpha = 0
            self.inputBar.alpha = 0
        } completion: { _ in
            results?.removeFromSuperview()
            self.resultsController.removeFromParent()
            self.inputBar.removeFromSuperview()
            self.installAccessory()
        }
    }
}
