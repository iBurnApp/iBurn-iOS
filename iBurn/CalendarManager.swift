//
//  CalendarManager.swift
//  iBurn
//
//  Created by Brice Pollock on 4/6/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import EventKit

class CalendarManager {
    public static let shared: CalendarManager()
    
    var eventStore: EKEventStore? {
        guard EKEventStore.authorizationStatus(for: .event) != .notDetermined else {
            BRCPermissions.promptForEvents {
                // no-p[
            }
            return nil
        }
        return store
    }
    
    private let store: EKEventStore
    
    private init() {
        store = EKEventStore()
    }
}
