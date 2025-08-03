//
//  DetailViewModelTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn

// Mock coordinator for tests
class MockTestDetailActionCoordinator: DetailActionCoordinator {
    func updateNavigator(_ navigator: (any iBurn.Navigable)?) {
    }
    
    func updatePresenter(_ presenter: (any iBurn.Presentable)?) {
    }
    
    var handledActions: [DetailAction] = []
    
    func handle(_ action: DetailAction) {
        handledActions.append(action)
    }
}

@MainActor
class DetailViewModelTests: XCTestCase {
    var viewModel: DetailViewModel!
    var mockDataService: MockDetailDataService!
    var mockAudioService: MockAudioService!
    var mockLocationService: MockLocationService!
    var mockCoordinator: MockTestDetailActionCoordinator!
    var capturedActions: [DetailAction] { mockCoordinator.handledActions }
    
    override func setUp() {
        super.setUp()
        mockDataService = MockDetailDataService()
        mockAudioService = MockAudioService()
        mockLocationService = MockLocationService()
        mockCoordinator = MockTestDetailActionCoordinator()
        
        viewModel = DetailViewModel(
            dataObject: MockDataObjects.artObject,
            dataService: mockDataService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            coordinator: mockCoordinator
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockDataService = nil
        mockAudioService = nil
        mockLocationService = nil
        mockCoordinator = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.dataObject.title, "Sample Art Installation")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.cells.isEmpty) // Not loaded until onAppear
    }
    
    func testInitializationWithExistingMetadata() {
        mockDataService.favoriteStatus = true
        
        let newViewModel = DetailViewModel(
            dataObject: MockDataObjects.artObject,
            dataService: mockDataService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            coordinator: MockTestDetailActionCoordinator()
        )
        
        XCTAssertTrue(newViewModel.metadata.isFavorite)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadData() async {
        await viewModel.loadData()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.cells.isEmpty)
    }
    
    
    // MARK: - Favorite Tests
    
    func testToggleFavoriteFromFalseToTrue() async {
        mockDataService.favoriteStatus = false
        viewModel.metadata.isFavorite = false
        
        await viewModel.toggleFavorite()
        
        XCTAssertTrue(mockDataService.updateFavoriteCalled)
        XCTAssertEqual(mockDataService.lastFavoriteValue, true)
        XCTAssertTrue(viewModel.metadata.isFavorite)
    }
    
    func testToggleFavoriteFromTrueToFalse() async {
        mockDataService.favoriteStatus = true
        viewModel.metadata.isFavorite = true
        
        await viewModel.toggleFavorite()
        
        XCTAssertTrue(mockDataService.updateFavoriteCalled)
        XCTAssertEqual(mockDataService.lastFavoriteValue, false)
        XCTAssertFalse(viewModel.metadata.isFavorite)
    }
    
    func testToggleFavoriteHandlesError() async {
        mockDataService.shouldThrowError = true
        
        await viewModel.toggleFavorite()
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error is DetailError)
    }
    
    
    // MARK: - Notes Tests
    
    func testUpdateNotes() async {
        let newNotes = "These are my new notes"
        
        await viewModel.updateNotes(newNotes)
        
        XCTAssertTrue(mockDataService.updateNotesCalled)
        XCTAssertEqual(viewModel.metadata.userNotes, newNotes)
    }
    
    func testUpdateNotesHandlesError() async {
        mockDataService.shouldThrowError = true
        
        await viewModel.updateNotes("New notes")
        
        XCTAssertTrue(mockDataService.updateNotesCalled)
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Cell Generation Tests
    
    func testCellGenerationForArtObject() async {
        await viewModel.loadData()
        
        let cells = viewModel.cells
        XCTAssertTrue(cells.contains { if case .text = $0.type { return true }; return false })
        
        // Should contain title
        let hasTitle = cells.contains { cell in
            if case .text(let text, let style) = cell.type {
                return text == "Sample Art Installation" && style == .title
            }
            return false
        }
        XCTAssertTrue(hasTitle)
    }
    
    func testCellGenerationForCampObject() async {
        let campViewModel = DetailViewModel(
            dataObject: MockDataObjects.campObject,
            dataService: mockDataService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            coordinator: MockTestDetailActionCoordinator()
        )
        
        await campViewModel.loadData()
        
        let cells = campViewModel.cells
        XCTAssertTrue(cells.contains { if case .text = $0.type { return true }; return false })
        XCTAssertTrue(cells.contains { if case .email = $0.type { return true }; return false })
    }
    
    func testCellGenerationForEventObject() async {
        let eventViewModel = DetailViewModel(
            dataObject: MockDataObjects.eventObject,
            dataService: mockDataService,
            audioService: mockAudioService,
            locationService: mockLocationService,
            coordinator: MockTestDetailActionCoordinator()
        )
        
        await eventViewModel.loadData()
        
        let cells = eventViewModel.cells
        XCTAssertTrue(cells.contains { if case .text = $0.type { return true }; return false })
        // Events should have schedule information
        let hasScheduleInfo = cells.contains { cell in
            if case .schedule = cell.type {
                return true
            }
            return false
        }
        XCTAssertTrue(hasScheduleInfo)
    }
    
    func testCellGenerationIncludesUserNotes() async {
        await viewModel.loadData()
        
        let cells = viewModel.cells
        let hasUserNotes = cells.contains { cell in
            if case .userNotes = cell.type {
                return true
            }
            return false
        }
        XCTAssertTrue(hasUserNotes)
    }
    
    // MARK: - Actions Tests
    
    func testCellTapEmailTriggerAction() {
        let emailCellType = DetailCellType.email("test@example.com", label: "Contact")
        let emailCell = DetailCell(emailCellType)
        
        viewModel.handleCellTap(emailCell)
        
        XCTAssertEqual(capturedActions.count, 1)
        if case .openEmail(let email) = capturedActions.first {
            XCTAssertEqual(email, "test@example.com")
        } else {
            XCTFail("Expected openEmail action")
        }
    }
    
    func testCellTapURLTriggersAction() {
        let url = URL(string: "https://example.com")!
        let urlCellType = DetailCellType.url(url, title: "Test")
        let urlCell = DetailCell(urlCellType)
        
        viewModel.handleCellTap(urlCell)
        
        XCTAssertEqual(capturedActions.count, 1)
        if case .openURL(let capturedURL) = capturedActions.first {
            XCTAssertEqual(capturedURL.absoluteString, "https://example.com")
        } else {
            XCTFail("Expected openURL action")
        }
    }
    
    func testCellTapRelationshipTriggersNavigation() {
        let relatedObject = MockDataObjects.campObject
        let relationshipCellType = DetailCellType.relationship(relatedObject, type: .relatedCamp)
        let relationshipCell = DetailCell(relationshipCellType)
        
        viewModel.handleCellTap(relationshipCell)
        
        XCTAssertEqual(capturedActions.count, 1)
        if case .navigateToObject(let object) = capturedActions.first {
            XCTAssertEqual(object.title, relatedObject.title)
        } else {
            XCTFail("Expected navigateToObject action")
        }
    }
    
    func testCellTapAudioTogglesPlayback() {
        let artObject = MockDataObjects.artObjectWithAudio
        let audioCellType = DetailCellType.audio(artObject, isPlaying: false)
        let audioCell = DetailCell(audioCellType)
        
        viewModel.handleCellTap(audioCell)
        
        XCTAssertTrue(mockAudioService.playAudioCalled)
        XCTAssertTrue(viewModel.isAudioPlaying)
    }
    
    func testCellTapAudioPausesWhenPlaying() {
        let artObject = MockDataObjects.artObjectWithAudio
        mockAudioService.currentlyPlaying = artObject
        
        let audioCellType = DetailCellType.audio(artObject, isPlaying: true)
        let audioCell = DetailCell(audioCellType)
        
        viewModel.handleCellTap(audioCell)
        
        XCTAssertTrue(mockAudioService.pauseAudioCalled)
        XCTAssertFalse(viewModel.isAudioPlaying)
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadDataHandlesErrors() async {
        // loadData() only calls getMetadata() which doesn't throw
        // Test that loadData() completes successfully even when data service is configured to throw
        mockDataService.shouldThrowError = true
        
        await viewModel.loadData()
        
        // loadData() should complete successfully since it doesn't call throwing methods
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.cells.isEmpty)
    }
}
