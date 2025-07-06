import Foundation
import PlayaAPI

/// Test helpers for creating mock API data
public enum MockAPIData {
    
    // MARK: - JSON Data
    
    public static let artJSON = """
    [
        {
            "uid": "a2IVI000000yWeZ2AU",
            "name": "Temple of the Deep",
            "year": 2025,
            "url": "https://www.2025temple.com/",
            "contact_email": "miguel@2025temple.com",
            "hometown": "Valencia, Spain",
            "description": "The Temple of the Deep is a sanctuary for grief, love, and introspection.",
            "artist": "Miguel Arraiz",
            "category": "Open Playa",
            "program": "Honorarium",
            "donation_link": "https://crowdfundr.com/2025temple",
            "location": null,
            "location_string": null,
            "images": [
                {
                    "thumbnail_url": "https://burningman.widen.net/content/jiicnlpjwu/jpeg/a2IVI000000yWeZ2AU-1.jpeg",
                    "gallery_ref": null
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
            "uid": "a1XVI000008yf262AA",
            "name": "Bag o' Dicks",
            "year": 2025,
            "url": null,
            "contact_email": "bagodicks.bm1@gmail.com",
            "hometown": "chicago",
            "description": "Free spirited camp with good beats, booze, and the friendliest bag o' dicks around!",
            "landmark": "3 neon dicks in the sky with sparkly come shots",
            "location": null,
            "location_string": null,
            "images": [
                {
                    "thumbnail_url": "https://burningman.widen.net/content/3ggbw9ehze/jpeg/a1XVI000008yf262AA-1.jpeg"
                }
            ]
        }
    ]
    """.data(using: .utf8)!
    
    public static let eventJSON = """
    [
        {
            "uid": "6Fzgz5paNv8ZbedcCQRw",
            "title": "Meowiokie",
            "event_id": 51387,
            "description": "Its karaoke but with meows. Come by and try",
            "event_type": {
                "label": "Music/Party",
                "abbr": "prty"
            },
            "year": 2025,
            "print_description": "",
            "slug": "6Fzgz5paNv8ZbedcCQRw-meowiokie",
            "hosted_by_camp": "a1XVI000009qe5p2AA",
            "located_at_art": null,
            "other_location": "",
            "check_location": false,
            "url": null,
            "all_day": false,
            "contact": null,
            "occurrence_set": [
                {
                    "start_time": "2025-08-27T12:00:00-07:00",
                    "end_time": "2025-08-27T13:00:00-07:00"
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
        name: "Temple of the Deep",
        year: 2025,
        url: URL(string: "https://www.2025temple.com/"),
        contactEmail: "miguel@2025temple.com",
        hometown: "Valencia, Spain",
        description: "The Temple of the Deep is a sanctuary for grief, love, and introspection.",
        artist: "Miguel Arraiz",
        category: "Open Playa",
        program: "Honorarium",
        donationLink: URL(string: "https://crowdfundr.com/2025temple"),
        images: [
            Image(thumbnailUrl: URL(string: "https://burningman.widen.net/content/jiicnlpjwu/jpeg/a2IVI000000yWeZ2AU-1.jpeg")!)
        ],
        selfGuidedTourMap: true
    )
    
    public static let mockCamp = Camp(
        uid: "a1XVI000008yf262AA",
        name: "Bag o' Dicks",
        year: 2025,
        contactEmail: "bagodicks.bm1@gmail.com",
        hometown: "chicago",
        description: "Free spirited camp with good beats, booze, and the friendliest bag o' dicks around!",
        landmark: "3 neon dicks in the sky with sparkly come shots",
        images: [
            Image(thumbnailUrl: URL(string: "https://burningman.widen.net/content/3ggbw9ehze/jpeg/a1XVI000008yf262AA-1.jpeg")!)
        ]
    )
    
    public static let mockEvent = Event(
        uid: "6Fzgz5paNv8ZbedcCQRw",
        title: "Meowiokie",
        eventId: 51387,
        description: "Its karaoke but with meows. Come by and try",
        eventType: EventType.musicParty,
        year: 2025,
        slug: "6Fzgz5paNv8ZbedcCQRw-meowiokie",
        hostedByCamp: "a1XVI000009qe5p2AA",
        occurrenceSet: [
            EventOccurrence(
                startTime: ISO8601DateFormatter().date(from: "2025-08-27T12:00:00-07:00")!,
                endTime: ISO8601DateFormatter().date(from: "2025-08-27T13:00:00-07:00")!
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