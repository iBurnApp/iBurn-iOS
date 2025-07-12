//
//  MockServices.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import Mantle

// MARK: - Mock Data Service

class MockDetailDataService: DetailDataServiceProtocol {
    var updateFavoriteCalled = false
    var updateNotesCalled = false
    var lastFavoriteValue: Bool?
    var favoriteStatus = false
    var shouldThrowError = false
    
    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws {
        updateFavoriteCalled = true
        lastFavoriteValue = isFavorite
        favoriteStatus = isFavorite
        
        if shouldThrowError {
            throw DetailError.updateFailed
        }
    }
    
    func updateUserNotes(for object: BRCDataObject, notes: String) async throws {
        updateNotesCalled = true
        
        if shouldThrowError {
            throw DetailError.updateFailed
        }
    }
    
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata? {
        guard let metadata = BRCObjectMetadata() else {
            return nil
        }
        metadata.isFavorite = favoriteStatus
        metadata.userNotes = "Sample notes for preview"
        return metadata
    }
}


// MARK: - Mock Audio Service

class MockAudioService: AudioServiceProtocol {
    var playAudioCalled = false
    var pauseAudioCalled = false
    var togglePlayPauseCalled = false
    var currentlyPlaying: BRCArtObject?
    
    func playAudio(artObjects: [BRCArtObject]) {
        playAudioCalled = true
        currentlyPlaying = artObjects.first
    }
    
    func pauseAudio() {
        pauseAudioCalled = true
        currentlyPlaying = nil
    }
    
    func isPlaying(artObject: BRCArtObject) -> Bool {
        return currentlyPlaying?.uniqueID == artObject.uniqueID
    }
    
    func togglePlayPause() {
        togglePlayPauseCalled = true
        if currentlyPlaying != nil {
            currentlyPlaying = nil
        }
    }
}

// MARK: - Mock Location Service

class MockLocationService: LocationServiceProtocol {
    var mockLocation: CLLocation?
    var startLocationUpdatesCalled = false
    var stopLocationUpdatesCalled = false
    
    init(mockLocation: CLLocation? = nil) {
        // Default to a location in Black Rock City
        self.mockLocation = mockLocation ?? CLLocation(latitude: 40.7864, longitude: -119.2065)
    }
    
    func getCurrentLocation() -> CLLocation? {
        return mockLocation
    }
    
    func distanceToObject(_ object: BRCDataObject) -> CLLocationDistance? {
        guard let currentLocation = mockLocation,
              let objectLocation = object.location else {
            return nil
        }
        
        return currentLocation.distance(from: objectLocation)
    }
    
    func startLocationUpdates() {
        startLocationUpdatesCalled = true
    }
    
    func stopLocationUpdates() {
        stopLocationUpdatesCalled = true
    }
}

// MARK: - Mock Data Objects

enum MockDataObjects {
    static let artObject: BRCArtObject = {
        // Create from JSON to properly set readonly properties
        let json: [String: Any] = [
            "uid": "art-123",
            "name": "Sample Art Installation",  // BRCArtObject uses "name" not "title"
            "description": "This is a beautiful art installation located on the playa. It represents the spirit of creativity and community that makes Burning Man special.",
            "artist": "Sample Artist",
            "location_string": "3:00 & 500'",  // Use correct JSON key
            "location": [
                "gps_latitude": 40.7900,
                "gps_longitude": -119.2100
            ],
            "url": "https://example.com",
            "contact_email": "artist@example.com",
            "year": 2024
        ]
        
        guard let art = try? MTLJSONAdapter.model(of: BRCArtObject.self, fromJSONDictionary: json) as? BRCArtObject else {
            fatalError("Failed to create mock art object - check JSON structure")
        }
        
        return art
    }()
    
    static let campObject: BRCCampObject = {
        let json: [String: Any] = [
            "uid": "camp-456",
            "name": "Sample Camp",  // Use "name" not "title"
            "description": "A welcoming camp with great vibes and amazing food. Come join us for coffee and conversation!",
            "contact_email": "camp@example.com",
            "location_string": "6:00 & Esplanade",  // Use correct JSON key
            "location": [
                "gps_latitude": 40.7850,
                "gps_longitude": -119.2050
            ],
            "url": "https://camp.example.com",
            "year": 2024
        ]
        
        guard let camp = try? MTLJSONAdapter.model(of: BRCCampObject.self, fromJSONDictionary: json) as? BRCCampObject else {
            fatalError("Failed to create mock camp object - check JSON structure")
        }
        
        return camp
    }()
    
    static let eventObject: BRCEventObject = {
        // Events use occurrence_set and are processed via BRCRecurringEventObject
        // For testing, we need to create a recurring event that generates BRCEventObject instances
        let json: [String: Any] = [
            "uid": "event-789",
            "title": "Sample Event",
            "event_id": 51387,
            "description": "An amazing event you won't want to miss. Dancing, music, and great people!",
            "event_type": [
                "label": "Music/Party",
                "abbr": "prty"
            ],
            "year": 2025,
            "print_description": "",
            "slug": "event-789-sample-event",
            "hosted_by_camp": "camp-456",
            "located_at_art": NSNull(),
            "other_location": "",
            "check_location": false,
            "url": "https://event.example.com",
            "all_day": false,
            "contact": "event@example.com",
            "occurrence_set": [
                [
                    "start_time": "2025-08-25T20:00:00-07:00",
                    "end_time": "2025-08-25T23:00:00-07:00"
                ]
            ]
        ]
        
        // Create a recurring event first, then extract the first event object
        if let recurringEvent = try? MTLJSONAdapter.model(of: BRCRecurringEventObject.self, fromJSONDictionary: json) as? BRCRecurringEventObject {
            let events = recurringEvent.eventObjects() as? [BRCEventObject] ?? []
            if let firstEvent = events.first {
                return firstEvent
            }
        }
        
        // Fallback - create empty event
        return BRCEventObject()!
    }()
    
    static let artObjectWithAudio: BRCArtObject = {
        let json: [String: Any] = [
            "uid": "art-audio-999",
            "name": "Audio Art Installation",  // Use "name" not "title"
            "description": "An art piece with an amazing audio tour experience.",
            "artist": "Audio Artist",
            "location_string": "9:00 & 300'",  // Use correct JSON key
            "location": [
                "gps_latitude": 40.7950,
                "gps_longitude": -119.2150
            ],
            "year": 2024,
            "audio_tour_url": "https://example.com/audio.mp3"  // Add audio URL
        ]
        
        guard let art = try? MTLJSONAdapter.model(of: BRCArtObject.self, fromJSONDictionary: json) as? BRCArtObject else {
            fatalError("Failed to create mock art object with audio - check JSON structure")
        }
        
        return art
    }()
}