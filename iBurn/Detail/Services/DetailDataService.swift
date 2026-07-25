//
//  DetailDataService.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaDB
import YapDatabase

/// Concrete implementation of DetailDataServiceProtocol
class DetailDataService: DetailDataServiceProtocol {
    private let playaDB: PlayaDB?

    /// PlayaDB-native calendar sync. When present *and*
    /// `Preferences.FeatureFlags.usePlayaDBCalendarSync` is on, it owns the EKEvents for
    /// favorited events and the legacy in-transaction `refreshCalendarEntry` is skipped,
    /// so exactly one stack writes calendar entries. Nil (tests/previews) keeps the
    /// legacy path.
    private let calendarService: EventCalendarService?

    init(playaDB: PlayaDB? = nil, calendarService: EventCalendarService? = nil) {
        self.playaDB = playaDB
        self.calendarService = calendarService
    }

    /// The calendar service to use for this write, or nil when the legacy Yap calendar
    /// path owns the entry.
    private var playaDBCalendarService: EventCalendarService? {
        guard let calendarService,
              PreferenceServiceFactory.shared.getValue(Preferences.FeatureFlags.usePlayaDBCalendarSync) else {
            return nil
        }
        return calendarService
    }

    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws {
        guard let metadata = getMetadata(for: object) else {
            throw DetailError.invalidData
        }

        let newMetadata = metadata.metadataCopy()
        newMetadata.isFavorite = isFavorite

        let calendarService = playaDBCalendarService

        await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)

                if calendarService == nil, let event = object as? BRCEventObject {
                    event.refreshCalendarEntry(transaction)
                }
            } completionBlock: {
                continuation.resume()
            }
        }

        // Post-commit, matching the FavoriteSyncService hook: the new service reads
        // PlayaDB, not the transaction. Yap event uids are per-occurrence
        // ("<apiUID>-<index>"); the service keys off the bare API uid.
        if let calendarService, object is BRCEventObject {
            let apiUID = FavoriteSyncServiceImpl.apiEventUID(fromYapUID: object.uniqueID)
            await calendarService.reconcile(eventUID: apiUID, isFavorite: isFavorite)
        }

        syncFavoriteToPlayaDB(for: object, isFavorite: isFavorite)
    }

    func updateUserNotes(for object: BRCDataObject, notes: String) async throws {
        guard let metadata = getMetadata(for: object) else {
            throw DetailError.invalidData
        }

        let newMetadata = metadata.metadataCopy()
        newMetadata.userNotes = notes

        await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)
            } completionBlock: {
                continuation.resume()
            }
        }

        syncNotesToPlayaDB(for: object, notes: notes)
    }
    
    func updateVisitStatus(for object: BRCDataObject, visitStatus: BRCVisitStatus) async throws {
        guard let metadata = getMetadata(for: object) else {
            throw DetailError.invalidData
        }
        
        let newMetadata = metadata.metadataCopy()
        newMetadata.visitStatus = visitStatus.rawValue
        
        await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)
            } completionBlock: {
                // Refresh the visit status grouped view to trigger real-time updates
                BRCDatabaseManager.shared.refreshVisitStatusGroupedView {
                    continuation.resume()
                }
            }
        }

        syncVisitStatusToPlayaDB(for: object, visitStatus: visitStatus)
    }
    
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata? {
        var metadata: BRCObjectMetadata?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            metadata = object.metadata(with: transaction)
        }
        
        return metadata
    }
    
    func canShowLocation(for object: BRCDataObject) -> Bool {
        return BRCEmbargo.canShowLocation(for: object)
    }
    
    func getCamp(withId id: String) -> BRCCampObject? {
        var camp: BRCCampObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            camp = transaction.object(forKey: id, inCollection: BRCCampObject.yapCollection) as? BRCCampObject
        }
        
        return camp
    }
    
    func getArt(withId id: String) -> BRCArtObject? {
        var art: BRCArtObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            art = transaction.object(forKey: id, inCollection: BRCArtObject.yapCollection) as? BRCArtObject
        }
        
        return art
    }
    
    func getEvents(for camp: BRCCampObject) -> [BRCEventObject]? {
        var events: [BRCEventObject] = []
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            events = camp.events(with: transaction)
        }
        
        return events.isEmpty ? nil : events
    }
    
    func getEvents(for art: BRCArtObject) -> [BRCEventObject]? {
        var events: [BRCEventObject] = []
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            events = art.events(with: transaction)
        }
        
        return events.isEmpty ? nil : events
    }
    
    func getNextEvent(forHostId hostId: String, after currentEvent: BRCEventObject) -> BRCEventObject? {
        var nextEvent: BRCEventObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            // Get all events for this host
            var allEvents: [BRCEventObject] = []
            
            // Try to get host as camp first
            if let camp = transaction.object(forKey: hostId, inCollection: BRCCampObject.yapCollection) as? BRCCampObject {
                allEvents = camp.events(with: transaction)
            }
            // If not found as camp, try as art
            else if let art = transaction.object(forKey: hostId, inCollection: BRCArtObject.yapCollection) as? BRCArtObject {
                allEvents = art.events(with: transaction)
            }
            
            // Filter out current event and get events that start after current event
            let currentStartDate = currentEvent.startDate
            let futureEvents = allEvents.filter { event in
                return event.uniqueID != currentEvent.uniqueID && 
                       event.startDate.compare(currentStartDate) == .orderedDescending
            }
            
            // Sort by start date and get the next one
            nextEvent = futureEvents.sorted { $0.startDate.compare($1.startDate) == .orderedAscending }.first
        }
        
        return nextEvent
    }
    
    func getOtherEventsCount(forHostId hostId: String, excluding currentEvent: BRCEventObject) -> Int {
        var count = 0
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            // Get all events for this host
            var allEvents: [BRCEventObject] = []
            
            // Try to get host as camp first
            if let camp = transaction.object(forKey: hostId, inCollection: BRCCampObject.yapCollection) as? BRCCampObject {
                allEvents = camp.events(with: transaction)
            }
            // If not found as camp, try as art
            else if let art = transaction.object(forKey: hostId, inCollection: BRCArtObject.yapCollection) as? BRCArtObject {
                allEvents = art.events(with: transaction)
            }
            
            // Count events excluding the current one
            count = allEvents.filter { $0.uniqueID != currentEvent.uniqueID }.count
        }
        
        return count
    }
    
    func getNextEvent(for camp: BRCCampObject) -> BRCEventObject? {
        var nextEvent: BRCEventObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            let allEvents = camp.events(with: transaction)
            let now = Date()
            
            // Get events that start after now
            let futureEvents = allEvents.filter { event in
                return event.startDate.compare(now) == .orderedDescending
            }
            
            // Sort by start date and get the next one
            nextEvent = futureEvents.sorted { $0.startDate.compare($1.startDate) == .orderedAscending }.first
        }
        
        return nextEvent
    }
    
    func getNextEvent(for art: BRCArtObject) -> BRCEventObject? {
        var nextEvent: BRCEventObject?

        BRCDatabaseManager.shared.uiConnection.read { transaction in
            let allEvents = art.events(with: transaction)
            let now = Date()

            // Get events that start after now
            let futureEvents = allEvents.filter { event in
                return event.startDate.compare(now) == .orderedDescending
            }

            // Sort by start date and get the next one
            nextEvent = futureEvents.sorted { $0.startDate.compare($1.startDate) == .orderedAscending }.first
        }

        return nextEvent
    }

    // MARK: - PlayaDB Sync

    private func syncFavoriteToPlayaDB(for object: BRCDataObject, isFavorite: Bool) {
        guard let playaDB else { return }
        let uid = object.uniqueID

        Task {
            do {
                if object is BRCArtObject, let art = try await playaDB.fetchArt(uid: uid) {
                    try await playaDB.setFavorite(isFavorite, for: art)
                } else if object is BRCEventObject {
                    // Yap event uniqueIDs are per-occurrence ("<apiUID>-<index>");
                    // PlayaDB stores events under the bare API uid, so strip the suffix.
                    let apiUID = FavoriteSyncServiceImpl.apiEventUID(fromYapUID: uid)
                    if let event = try await playaDB.fetchEvent(uid: apiUID) {
                        try await playaDB.setFavorite(isFavorite, for: event)
                    }
                } else if object is BRCCampObject, let camp = try await playaDB.fetchCamp(uid: uid) {
                    try await playaDB.setFavorite(isFavorite, for: camp)
                }
            } catch {
                print("PlayaDB favorite sync failed for \(uid): \(error)")
            }
        }
    }

    private func syncVisitStatusToPlayaDB(for object: BRCDataObject, visitStatus: BRCVisitStatus) {
        guard let playaDB else { return }
        let uid = object.uniqueID
        let status = VisitStatus(rawValue: visitStatus.rawValue) ?? .unvisited

        Task {
            do {
                if object is BRCArtObject, let art = try await playaDB.fetchArt(uid: uid) {
                    try await playaDB.setVisitStatus(status, for: art)
                } else if object is BRCEventObject {
                    // Same per-occurrence uid mapping as favorite sync above:
                    // Yap event uniqueIDs are "<apiUID>-<index>", PlayaDB keys by bare API uid.
                    let apiUID = FavoriteSyncServiceImpl.apiEventUID(fromYapUID: uid)
                    if let event = try await playaDB.fetchEvent(uid: apiUID) {
                        try await playaDB.setVisitStatus(status, for: event)
                    }
                } else if object is BRCCampObject, let camp = try await playaDB.fetchCamp(uid: uid) {
                    try await playaDB.setVisitStatus(status, for: camp)
                }
            } catch {
                print("PlayaDB visit status sync failed for \(uid): \(error)")
            }
        }
    }

    private func syncNotesToPlayaDB(for object: BRCDataObject, notes: String) {
        guard let playaDB else { return }
        let uid = object.uniqueID

        Task {
            do {
                if object is BRCArtObject, let art = try await playaDB.fetchArt(uid: uid) {
                    try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: art)
                } else if object is BRCEventObject {
                    // Same per-occurrence uid mapping as favorite sync above.
                    let apiUID = FavoriteSyncServiceImpl.apiEventUID(fromYapUID: uid)
                    if let event = try await playaDB.fetchEvent(uid: apiUID) {
                        try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: event)
                    }
                } else if object is BRCCampObject, let camp = try await playaDB.fetchCamp(uid: uid) {
                    try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: camp)
                }
            } catch {
                print("PlayaDB notes sync failed for \(uid): \(error)")
            }
        }
    }
}