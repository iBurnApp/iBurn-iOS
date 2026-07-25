//
//  EmbargoNotification.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

extension Notification.Name {
    /// Posted on the main thread when embargoed location data becomes visible.
    ///
    /// Unlocking only flips a `UserDefaults` flag (`BRCEmbargo.allowEmbargoedData`), which is
    /// read imperatively all over the app — most importantly by live PlayaDB observations
    /// (`PlayaDBAnnotationDataSource.startObserving`) and by SwiftUI list rows that hide playa
    /// addresses. Nothing re-reads that flag on its own, so without this notification newly
    /// unlocked locations only appear after an app relaunch.
    ///
    /// Posted from both unlock paths: passcode entry
    /// (`EmbargoPasscodeViewModel.unlockButtonPressed`) and region-based unlock
    /// (`BRCAppDelegate.enteredBurningManRegion`).
    static let BRCEmbargoDidClear = Notification.Name(BRCEmbargoNotifier.didClearNotificationName)
}

/// Objective-C visible poster for `Notification.Name.BRCEmbargoDidClear`.
///
/// `Notification.Name` extensions are invisible to Objective-C, so `BRCAppDelegate` posts
/// through this shim instead of hard-coding the raw notification string.
@objc(BRCEmbargoNotifier)
public final class BRCEmbargoNotifier: NSObject {

    /// Raw name backing `Notification.Name.BRCEmbargoDidClear`.
    @objc public static let didClearNotificationName = "BRCEmbargoDidClearNotification"

    /// Posts `.BRCEmbargoDidClear`, hopping to the main thread when needed so observers
    /// (map data sources, hosting controllers) can update UI synchronously.
    @objc public static func postDidClear() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .BRCEmbargoDidClear, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .BRCEmbargoDidClear, object: nil)
            }
        }
    }
}
