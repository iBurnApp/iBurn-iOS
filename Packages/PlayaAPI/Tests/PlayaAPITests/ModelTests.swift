import XCTest
@testable import PlayaAPI
import PlayaAPITestHelpers

final class ModelTests: XCTestCase {
    
    // MARK: - Identifier Tests
    
    func testArtID_StringLiteralInitialization() {
        let id: ArtID = "test-art-id"
        XCTAssertEqual(id.value, "test-art-id")
    }
    
    func testCampID_StringLiteralInitialization() {
        let id: CampID = "test-camp-id"
        XCTAssertEqual(id.value, "test-camp-id")
    }
    
    func testEventID_StringLiteralInitialization() {
        let id: EventID = "test-event-id"
        XCTAssertEqual(id.value, "test-event-id")
    }
    
    func testIdentifiers_Hashable() {
        let artID1: ArtID = "test-id"
        let artID2: ArtID = "test-id"
        let artID3: ArtID = "different-id"
        
        XCTAssertEqual(artID1, artID2)
        XCTAssertNotEqual(artID1, artID3)
        
        let set: Set<ArtID> = [artID1, artID2, artID3]
        XCTAssertEqual(set.count, 2) // artID1 and artID2 should be treated as same
    }
    
    // MARK: - Art Model Tests
    
    func testArt_ComputedProperties() {
        let art = MockAPIData.mockArt
        
        XCTAssertTrue(art.hasImages)
        XCTAssertTrue(art.hasLocation) // Mock data has location
        XCTAssertTrue(art.hasTours) // selfGuidedTourMap is true
        XCTAssertTrue(art.hasContact) // Has email and URL
    }
    
    func testArt_NoImagesOrContact() {
        let art = Art(
            uid: "test-id",
            name: "Test Art",
            year: 2025
        )
        
        XCTAssertFalse(art.hasImages)
        XCTAssertFalse(art.hasLocation)
        XCTAssertFalse(art.hasTours)
        XCTAssertFalse(art.hasContact)
    }
    
    // MARK: - Camp Model Tests
    
    func testCamp_ComputedProperties() {
        let camp = MockAPIData.mockCamp
        
        XCTAssertFalse(camp.hasImages) // Mock camp has empty images array
        XCTAssertTrue(camp.hasLocation) // Mock data has location
        XCTAssertTrue(camp.hasLandmark)
        XCTAssertTrue(camp.hasContact) // Has email
        XCTAssertTrue(camp.hasDescription)
    }
    
    func testCamp_EmptyLandmark() {
        let camp = Camp(
            uid: "test-id",
            name: "Test Camp",
            year: 2025,
            landmark: ""
        )
        
        XCTAssertFalse(camp.hasLandmark)
    }
    
    // MARK: - Event Model Tests
    
    func testEvent_ComputedProperties() {
        let event = MockAPIData.mockEvent
        
        XCTAssertTrue(event.hasOccurrences)
        XCTAssertTrue(event.hasLocation) // Has hostedByCamp
        XCTAssertFalse(event.hasContact) // Mock data has no contact info
        XCTAssertTrue(event.hasDescription)
    }
    
    func testEvent_NextOccurrence() {
        let now = Date()
        let futureDate1 = now.addingTimeInterval(3600) // 1 hour from now
        let futureDate2 = now.addingTimeInterval(7200) // 2 hours from now
        
        let event = Event(
            uid: "test-id",
            title: "Test Event",
            eventId: 123,
            eventType: EventTypeInfo(label: "Music/Party", type: .gatheringParty),
            year: 2025,
            slug: "test-event",
            occurrenceSet: [
                EventOccurrence(startTime: futureDate2, endTime: futureDate2.addingTimeInterval(3600)),
                EventOccurrence(startTime: futureDate1, endTime: futureDate1.addingTimeInterval(3600))
            ]
        )
        
        XCTAssertEqual(event.nextOccurrence(now)?.startTime, futureDate1)
    }
    
    func testEvent_CurrentOccurrence() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-3600) // 1 hour ago
        let futureDate = now.addingTimeInterval(3600) // 1 hour from now
        
        let event = Event(
            uid: "test-id",
            title: "Test Event",
            eventId: 123,
            eventType: EventTypeInfo(label: "Music/Party", type: .gatheringParty),
            year: 2025,
            slug: "test-event",
            occurrenceSet: [
                EventOccurrence(startTime: pastDate, endTime: futureDate) // Currently happening
            ]
        )
        
        XCTAssertNotNil(event.currentOccurrence(now))
        XCTAssertTrue(event.isCurrentlyHappening(now))
    }
    
    // MARK: - EventOccurrence Tests
    
    func testEventOccurrence_ComputedProperties() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour duration
        let occurrence = EventOccurrence(startTime: start, endTime: end)
        
        XCTAssertEqual(occurrence.duration, 3600)
        XCTAssertTrue(occurrence.isCurrentlyHappening())
        XCTAssertFalse(occurrence.hasEnded())
        XCTAssertFalse(occurrence.isFuture())
    }
    
    func testEventOccurrence_PastEvent() {
        let start = Date().addingTimeInterval(-7200) // 2 hours ago
        let end = Date().addingTimeInterval(-3600) // 1 hour ago
        let occurrence = EventOccurrence(startTime: start, endTime: end)
        
        XCTAssertFalse(occurrence.isCurrentlyHappening())
        XCTAssertTrue(occurrence.hasEnded())
        XCTAssertFalse(occurrence.isFuture())
    }
    
    func testEventOccurrence_FutureEvent() {
        let start = Date().addingTimeInterval(3600) // 1 hour from now
        let end = Date().addingTimeInterval(7200) // 2 hours from now
        let occurrence = EventOccurrence(startTime: start, endTime: end)
        
        XCTAssertFalse(occurrence.isCurrentlyHappening())
        XCTAssertFalse(occurrence.hasEnded())
        XCTAssertTrue(occurrence.isFuture())
    }
    
    // MARK: - UpdateInfo Tests
    
    func testUpdateInfo_ComputedProperties() {
        let updateInfo = MockAPIData.mockUpdateInfo
        
        XCTAssertNotNil(updateInfo.lastUpdated)
        XCTAssertTrue(updateInfo.hasUpdates)
        
        // Should return the latest date among all updates
        let expectedLatest = updateInfo.camps?.updated // This is the latest in mock data
        XCTAssertEqual(updateInfo.lastUpdated, expectedLatest)
    }
    
    func testUpdateInfo_EmptyUpdates() {
        let updateInfo = UpdateInfo()
        
        XCTAssertNil(updateInfo.lastUpdated)
        XCTAssertFalse(updateInfo.hasUpdates)
    }
    
    // MARK: - EventType Tests
    
    func testEventType_StringEnumValues() {
        XCTAssertEqual(EventType.gatheringParty.rawValue, "prty")
        XCTAssertEqual(EventType.classWorkshop.rawValue, "work")
        XCTAssertEqual(EventType.artsAndCrafts.rawValue, "arts")
        XCTAssertEqual(EventType.matureAudiences.rawValue, "adlt")
        XCTAssertEqual(EventType.forKids.rawValue, "kid")
        XCTAssertEqual(EventType.foodAndDrink.rawValue, "food")
        XCTAssertEqual(EventType.coffeeTea.rawValue, "tea")
        XCTAssertEqual(EventType.miscellaneous.rawValue, "othr")
        XCTAssertEqual(EventType.ritualCeremony.rawValue, "cere")
        XCTAssertEqual(EventType.games.rawValue, "game")
        XCTAssertEqual(EventType.performance.rawValue, "perf")
        XCTAssertEqual(EventType.selfCare.rawValue, "care")
        XCTAssertEqual(EventType.fireSpectacle.rawValue, "fire")
        XCTAssertEqual(EventType.parade.rawValue, "para")
        XCTAssertEqual(EventType.none.rawValue, "none")
        XCTAssertEqual(EventType.healingMassageSpa.rawValue, "heal")
        XCTAssertEqual(EventType.lgbtqia2s.rawValue, "LGBT")
        XCTAssertEqual(EventType.liveMusic.rawValue, "live")
        XCTAssertEqual(EventType.diversityInclusion.rawValue, "RIDE")
        XCTAssertEqual(EventType.repair.rawValue, "repr")
        XCTAssertEqual(EventType.sustainabilityGreening.rawValue, "sust")
        XCTAssertEqual(EventType.yogaMovementFitness.rawValue, "yoga")
    }
    
    // MARK: - Image Tests
    
    func testArtImage_Initialization() {
        let url = URL(string: "https://example.com/image.jpg")!
        let image = ArtImage(thumbnailUrl: url, galleryRef: "gallery-123")
        
        XCTAssertEqual(image.thumbnailUrl, url)
        XCTAssertEqual(image.galleryRef, "gallery-123")
    }
    
    func testCampImage_Initialization() {
        let url = URL(string: "https://example.com/image.jpg")!
        let image = CampImage(thumbnailUrl: url)
        
        XCTAssertEqual(image.thumbnailUrl, url)
    }
}
