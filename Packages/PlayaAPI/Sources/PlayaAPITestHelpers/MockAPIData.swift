import Foundation
import PlayaAPI

/// Test helpers for creating mock API data
public enum MockAPIData {
    
    // MARK: - JSON Data
    
    public static let artJSON = """
    [
        {
            "uid": "a2IVI000000yWeZ2AU",
            "name": "Burning Questions",
            "year": 2025,
            "url": "https://www.burningquestions.com/",
            "contact_email": "artist@burningquestions.com",
            "hometown": "San Francisco, CA",
            "description": "An interactive art installation exploring curiosity and wonder.",
            "artist": "Jane Smith",
            "category": "Open Playa",
            "program": "Honorarium",
            "donation_link": "https://crowdfundr.com/burningquestions",
            "location": {
                "hour": 12,
                "minute": 0,
                "distance": 2500,
                "category": "Open Playa",
                "gps_latitude": 40.79179890754886,
                "gps_longitude": -119.1976993927176
            },
            "location_string": "12:00 2500', Open Playa",
            "images": [
                {
                    "thumbnail_url": "https://example.com/art-image.jpeg",
                    "gallery_ref": "gallery-123"
                }
            ],
            "guided_tours": false,
            "self_guided_tour_map": true
        }
    ]
    """.data(using: .utf8)!
    
    public static let campJSON = """
    [
        {
            "uid": "a1XVI000008zSaf2AE",
            "name": "Camp ASL Support Services HUB",
            "year": 2025,
            "url": null,
            "contact_email": "ddhplanb@gmail.com",
            "hometown": "All over, north, and, South America",
            "description": "American sign language Support services. Centralized services for the Deaf.",
            "landmark": "American sign language support services sign",
            "location": {
                "frontage": "Esplanade",
                "intersection": "6:30",
                "intersection_type": "&",
                "dimensions": "75 x 110",
                "exact_location": "Mid-block facing 10:00"
            },
            "location_string": "Esplanade & 6:30",
            "images": []
        }
    ]
    """.data(using: .utf8)!
    
    public static let eventJSON = """
    [
        {
            "uid": "78ZvNxSeeZQbaeHuughD",
            "title": "Fairycore Tarot Meetup",
            "event_id": 51138,
            "description": "First time picking up cards? A professional reader? All levels welcome",
            "event_type": {
                "label": "Class/Workshop",
                "abbr": "work"
            },
            "year": 2025,
            "print_description": "",
            "slug": "78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup",
            "hosted_by_camp": "a1XVI000009t6XR2AY",
            "located_at_art": null,
            "other_location": "",
            "check_location": false,
            "url": null,
            "all_day": false,
            "contact": null,
            "occurrence_set": [
                {
                    "start_time": "2025-08-28T12:00:00-07:00",
                    "end_time": "2025-08-28T13:30:00-07:00"
                }
            ]
        }
    ]
    """.data(using: .utf8)!
    
    public static let updateInfoJSON = """
    {
        "art": {
            "file": "art.json",
            "updated": "2025-07-28T11:51:02-07:00"
        },
        "camps": {
            "file": "camp.json",
            "updated": "2025-07-28T11:58:02-07:00"
        },
        "events": {
            "file": "event.json",
            "updated": "2025-07-28T11:58:02-07:00"
        }
    }
    """.data(using: .utf8)!
    
    // MARK: - Mock Objects
    
    public static let mockArt = Art(
        uid: "a2IVI000000yWeZ2AU",
        name: "Burning Questions",
        year: 2025,
        url: URL(string: "https://www.burningquestions.com/"),
        contactEmail: "artist@burningquestions.com",
        hometown: "San Francisco, CA",
        description: "An interactive art installation exploring curiosity and wonder.",
        artist: "Jane Smith",
        category: "Open Playa",
        program: "Honorarium",
        donationLink: URL(string: "https://crowdfundr.com/burningquestions"),
        location: ArtLocation(
            hour: 12,
            minute: 0,
            distance: 2500,
            category: "Open Playa",
            gpsLatitude: 40.79179890754886,
            gpsLongitude: -119.1976993927176
        ),
        locationString: "12:00 2500', Open Playa",
        images: [
            ArtImage(
                thumbnailUrl: URL(string: "https://example.com/art-image.jpeg"),
                galleryRef: "gallery-123"
            )
        ],
        selfGuidedTourMap: true
    )
    
    public static let mockCamp = Camp(
        uid: "a1XVI000008zSaf2AE",
        name: "Camp ASL Support Services HUB",
        year: 2025,
        contactEmail: "ddhplanb@gmail.com",
        hometown: "All over, north, and, South America",
        description: "American sign language Support services. Centralized services for the Deaf.",
        landmark: "American sign language support services sign",
        location: CampLocation(
            frontage: "Esplanade",
            intersection: "6:30",
            intersectionType: "&",
            dimensions: "75 x 110",
            exactLocation: "Mid-block facing 10:00"
        ),
        locationString: "Esplanade & 6:30",
        images: []
    )
    
    public static let mockEvent = Event(
        uid: "78ZvNxSeeZQbaeHuughD",
        title: "Fairycore Tarot Meetup",
        eventId: 51138,
        description: "First time picking up cards? A professional reader? All levels welcome",
        eventType: EventTypeInfo(label: "Class/Workshop", type: .classWorkshop),
        year: 2025,
        slug: "78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup",
        hostedByCamp: "a1XVI000009t6XR2AY",
        occurrenceSet: [
            EventOccurrence(
                startTime: ISO8601DateFormatter().date(from: "2025-08-28T12:00:00-07:00"),
                endTime: ISO8601DateFormatter().date(from: "2025-08-28T13:30:00-07:00")
            )
        ]
    )
    
    public static let mockUpdateInfo = UpdateInfo(
        art: FileUpdateInfo(
            file: "art.json",
            updated: ISO8601DateFormatter().date(from: "2025-07-28T11:51:02-07:00")!
        ),
        camps: FileUpdateInfo(
            file: "camp.json",
            updated: ISO8601DateFormatter().date(from: "2025-07-28T11:58:02-07:00")!
        ),
        events: FileUpdateInfo(
            file: "event.json",
            updated: ISO8601DateFormatter().date(from: "2025-07-28T11:58:02-07:00")!
        )
    )
}
