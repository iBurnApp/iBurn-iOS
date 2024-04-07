//
//  Logger.swift
//  iBurn
//
//  Created by Brice Pollock on 4/6/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import OSLog

extension Logger {
        private static var subsystem = Bundle.main.bundleIdentifier!

        public static let calendarEvent = Logger(subsystem: subsystem, category: "CalendarEvent")
}
