//
//  BRCDataObject+EmojiMarker.swift
//  iBurn
//
//  Created by Assistant on 2025-08-09.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit

extension BRCDataObject {
    
    /// User defaults key for emoji map icons preference
    @objc static let emojiMapIconsKey = "BRCEmojiMapIconsEnabled"
    
    /// Check if emoji map icons are enabled
    @objc static var emojiMapIconsEnabled: Bool {
        UserDefaults.standard.bool(forKey: emojiMapIconsKey)
    }
    
    /// Set emoji map icons preference
    @objc static func setEmojiMapIconsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: emojiMapIconsKey)
        NotificationCenter.default.post(name: .emojiMapIconsSettingChanged, object: nil)
    }
    
    /// Get the emoji marker image for this data object
    @objc func emojiMarkerImage() -> UIImage? {
        let emoji: String
        var configuration = EmojiImageRenderer.Configuration.mapPin
        
        if let artObject = self as? BRCArtObject {
            emoji = artObject.emoji
        } else if let campObject = self as? BRCCampObject {
            emoji = campObject.emoji
        } else if let eventObject = self as? BRCEventObject {
            emoji = BRCEventObject.emoji(forEventType: eventObject.eventType)
            
            // Apply event status colors
            let statusColor = eventStatusColor(for: eventObject, at: Date.present)
            if let color = statusColor {
                configuration = .mapPinWithStatus(color: color)
            }
        } else {
            // Default emoji for unknown types
            emoji = "📍"
        }
        
        return EmojiImageRenderer.shared.renderEmoji(emoji, configuration: configuration)
    }
    
    /// Get the status color for an event
    private func eventStatusColor(for event: BRCEventObject, at date: Date) -> UIColor? {
        if event.isStartingSoon(date) {
            return .systemGreen
        } else if event.isEndingSoon(date) {
            return .systemOrange
        } else if event.hasEnded(date) {
            return .systemRed
        } else if event.isHappeningRightNow(date) {
            return .systemGreen
        }
        return nil
    }
}

// MARK: - Notification

extension Notification.Name {
    static let emojiMapIconsSettingChanged = Notification.Name("BRCEmojiMapIconsSettingChanged")
}