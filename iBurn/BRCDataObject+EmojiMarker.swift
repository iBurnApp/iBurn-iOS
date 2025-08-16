//
//  BRCDataObject+EmojiMarker.swift
//  iBurn
//
//  Created by Assistant on 2025-08-09.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit

extension BRCDataObject {
    
    /// Get the emoji marker image for this data object
    @objc func emojiMarkerImage() -> UIImage? {
        let emoji: String
        var configuration = EmojiImageRenderer.Configuration.mapPin
        
        // Check if object is favorited and get visit status
        var isFavorite = false
        var visitStatus = 0
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            let metadata = self.metadata(with: transaction)
            isFavorite = metadata.isFavorite
            visitStatus = metadata.visitStatus
        }
        
        if let artObject = self as? BRCArtObject {
            emoji = artObject.emoji
            configuration = .mapPinWithStatus(isFavorite: isFavorite, visitStatus: visitStatus)
        } else if let campObject = self as? BRCCampObject {
            emoji = campObject.emoji
            configuration = .mapPinWithStatus(isFavorite: isFavorite, visitStatus: visitStatus)
        } else if let eventObject = self as? BRCEventObject {
            emoji = eventObject.eventType.emoji
            
            // Apply event status colors
            let statusColor = eventStatusColor(for: eventObject, at: Date.present)
            configuration = .mapPinWithStatus(color: statusColor, isFavorite: isFavorite, visitStatus: visitStatus)
        } else {
            // Default emoji for unknown types
            emoji = "📍"
            configuration = .mapPinWithStatus(isFavorite: isFavorite, visitStatus: visitStatus)
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
