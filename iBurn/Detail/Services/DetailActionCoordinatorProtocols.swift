//
//  DetailActionCoordinatorProtocols.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

// MARK: - Minimal UIKit Protocols

/// Protocol for objects that can present view controllers
protocol Presentable: AnyObject {
    func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)?)
    func dismiss(animated flag: Bool, completion: (() -> Void)?)
}

/// Protocol for objects that can push view controllers
protocol Navigable: AnyObject {
    func pushViewController(_ viewController: UIViewController, animated: Bool)
}

// MARK: - UIKit Conformance

extension UIViewController: Presentable {}
extension UINavigationController: Navigable {}
