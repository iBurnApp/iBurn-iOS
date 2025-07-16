//
//  DynamicViewControllerProtocols.swift
//  iBurn
//
//  Created by Claude Code on 7/13/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

// MARK: - Event Types

/// Events that view controllers can notify their containers about
public enum ViewControllerEvent {
    case viewWillLayoutSubviews
    case navigationItemDidChange  
    case toolbarDidChange
    case viewDidAppear
    case viewWillDisappear
}

// MARK: - Protocols

/// Protocol for containers that want to receive view controller lifecycle events
public protocol DynamicViewControllerEventHandler: AnyObject {
    /// Called when a view controller triggers an event
    /// - Parameters:
    ///   - event: The type of event that occurred
    ///   - sender: The view controller that triggered the event
    func viewControllerDidTriggerEvent(_ event: ViewControllerEvent, sender: UIViewController)
}

/// Protocol for view controllers that can notify containers about lifecycle events
public protocol DynamicViewController: AnyObject {
    /// The handler that will receive event notifications
    var eventHandler: DynamicViewControllerEventHandler? { get set }
    
    /// Notify the event handler about an event
    /// - Parameter event: The event that occurred
    func notifyEventHandler(_ event: ViewControllerEvent)
}

// MARK: - Default Implementation

public extension DynamicViewController where Self: UIViewController {
    /// Default implementation that safely calls the event handler
    func notifyEventHandler(_ event: ViewControllerEvent) {
        eventHandler?.viewControllerDidTriggerEvent(event, sender: self)
    }
}