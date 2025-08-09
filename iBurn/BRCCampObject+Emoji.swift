//
//  BRCCampObject+Emoji.swift
//  iBurn
//
//  Created by Assistant on 2025-08-09.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCCampObject {
    /// Emoji representation for camps
    @objc var emoji: String {
        // Could be enhanced based on camp type or services
        // For now, using tent emoji for all camps
        return "⛺"
    }
}