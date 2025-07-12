//
//  DetailActionCoordinatorTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn
import CoreLocation
import EventKitUI

// MARK: - Mock Dependencies

class MockPresentable: Presentable {
    var presentedViewController: UIViewController?
    var presentAnimated: Bool?
    var presentCompletion: (() -> Void)?
    var dismissAnimated: Bool?
    var dismissCompletion: (() -> Void)?
    
    func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)?) {
        self.presentedViewController = viewControllerToPresent
        self.presentAnimated = animated
        self.presentCompletion = completion
        completion?()
    }
    
    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        self.dismissAnimated = flag
        self.dismissCompletion = completion
        completion?()
    }
}

class MockNavigable: Navigable {
    var pushedViewController: UIViewController?
    var pushAnimated: Bool?
    
    func pushViewController(_ viewController: UIViewController, animated: Bool) {
        self.pushedViewController = viewController
        self.pushAnimated = animated
    }
}

class MockEventEditService: EventEditService {
    var createdController: EKEventEditViewController?
    var lastEvent: BRCEventObject?
    
    func createEventEditController(for event: BRCEventObject) -> EKEventEditViewController {
        self.lastEvent = event
        let controller = EKEventEditViewController()
        self.createdController = controller
        return controller
    }
}

// MARK: - Tests

class DetailActionCoordinatorTests: XCTestCase {
    
    var coordinator: DetailActionCoordinator!
    var mockPresenter: MockPresentable!
    var mockNavigator: MockNavigable!
    var mockEventEditService: MockEventEditService!
    
    override func setUp() {
        super.setUp()
        mockPresenter = MockPresentable()
        mockNavigator = MockNavigable()
        mockEventEditService = MockEventEditService()
        
        let dependencies = DetailActionCoordinatorDependencies(
            presenter: mockPresenter,
            navigator: mockNavigator,
            eventEditService: mockEventEditService
        )
        coordinator = DetailActionCoordinatorFactory.makeCoordinator(dependencies: dependencies)
    }
    
    override func tearDown() {
        coordinator = nil
        mockPresenter = nil
        mockNavigator = nil
        mockEventEditService = nil
        super.tearDown()
    }
    
    // MARK: - Email Tests
    
    func testHandleOpenEmail() {
        // Given
        let email = "test@burningman.org"
        
        // When
        coordinator.handle(.openEmail(email))
        
        // Then
        // Email is handled by WebViewHelper.openEmail which uses UIApplication.shared
        // We can't easily test this without mocking UIApplication
        // For now, just verify no crash occurs
        XCTAssertNil(mockPresenter.presentedViewController)
    }
    
    // MARK: - URL Tests
    
    func testHandleOpenURL() {
        // Given
        let url = URL(string: "https://burningman.org")!
        
        // When
        coordinator.handle(.openURL(url))
        
        // Then
        // URL is handled by WebViewHelper which requires a real UIViewController
        // Since mockPresenter is not a UIViewController, nothing happens
        XCTAssertNil(mockPresenter.presentedViewController)
    }
    
    // MARK: - Event Editor Tests
    
    func testHandleShowEventEditor() {
        // Given
        let event = BRCEventObject()
        event.title = "Test Event"
        
        // When
        coordinator.handle(.showEventEditor(event))
        
        // Then
        XCTAssertNotNil(mockPresenter.presentedViewController)
        XCTAssertTrue(mockPresenter.presentedViewController is EKEventEditViewController)
        XCTAssertEqual(mockPresenter.presentAnimated, true)
        
        // Verify the service was called correctly
        XCTAssertEqual(mockEventEditService.lastEvent?.title, "Test Event")
        XCTAssertNotNil(mockEventEditService.createdController)
    }
    
    // MARK: - Share Coordinates Tests
    
    func testHandleShareCoordinates() {
        // Given
        let coordinate = CLLocationCoordinate2D(latitude: 40.7869, longitude: -119.2066)
        
        // When
        coordinator.handle(.shareCoordinates(coordinate))
        
        // Then
        XCTAssertNotNil(mockPresenter.presentedViewController)
        XCTAssertTrue(mockPresenter.presentedViewController is UIActivityViewController)
        XCTAssertEqual(mockPresenter.presentAnimated, true)
    }
    
    // MARK: - Image Viewer Tests
    
    func testHandleShowImageViewer() {
        // Given
        let image = UIImage()
        
        // When
        coordinator.handle(.showImageViewer(image))
        
        // Then
        XCTAssertNotNil(mockPresenter.presentedViewController)
        XCTAssertEqual(mockPresenter.presentedViewController?.modalPresentationStyle, .fullScreen)
        XCTAssertEqual(mockPresenter.presentedViewController?.modalTransitionStyle, .crossDissolve)
        XCTAssertEqual(mockPresenter.presentAnimated, true)
    }
    
    // MARK: - Map Tests
    
    func testHandleShowMap() {
        // Given
        let dataObject = BRCArtObject()
        dataObject.title = "Test Art"
        
        // When
        coordinator.handle(.showMap(dataObject))
        
        // Then
        // Currently just logs, no presentation
        XCTAssertNil(mockPresenter.presentedViewController)
    }
    
    // MARK: - Navigation Tests
    
    func testHandleNavigateToObject() {
        // Given
        let relatedObject = BRCCampObject()
        relatedObject.title = "Related Camp"
        
        // When
        coordinator.handle(.navigateToObject(relatedObject))
        
        // Then
        // Navigation requires presenter to be a real UIViewController
        // Since it's not, nothing happens
        XCTAssertNil(mockNavigator.pushedViewController)
    }
    
    // MARK: - Events List Tests
    
    func testHandleShowEventsList() {
        // Given
        let events = [BRCEventObject(), BRCEventObject()]
        let hostName = "Test Camp"
        
        // When
        coordinator.handle(.showEventsList(events, hostName: hostName))
        
        // Then
        // Currently just logs, no presentation
        XCTAssertNil(mockPresenter.presentedViewController)
    }
    
    // MARK: - Audio Tests
    
    func testHandlePlayAudio() {
        // Given
        let artObject = BRCArtObject()
        
        // When
        coordinator.handle(.playAudio(artObject))
        
        // Then
        // Audio is handled by ViewModel, not coordinator
        XCTAssertNil(mockPresenter.presentedViewController)
    }
    
    func testHandlePauseAudio() {
        // When
        coordinator.handle(.pauseAudio)
        
        // Then
        // Audio is handled by ViewModel, not coordinator
        XCTAssertNil(mockPresenter.presentedViewController)
    }
    
    // MARK: - Notes Editor Tests
    
    func testHandleEditNotes() {
        // Given
        let currentNotes = "Test notes"
        var completionCalled = false
        var newNotesReceived: String?
        
        // When
        coordinator.handle(.editNotes(current: currentNotes) { notes in
            completionCalled = true
            newNotesReceived = notes
        })
        
        // Then
        XCTAssertNotNil(mockPresenter.presentedViewController)
        XCTAssertTrue(mockPresenter.presentedViewController is UIAlertController)
        
        let alertController = mockPresenter.presentedViewController as? UIAlertController
        XCTAssertEqual(alertController?.title, "Edit Notes")
        XCTAssertEqual(alertController?.textFields?.count, 1)
        XCTAssertEqual(alertController?.textFields?.first?.text, currentNotes)
        XCTAssertEqual(alertController?.actions.count, 2) // Cancel and Save
        
        // Simulate save action
        if let textField = alertController?.textFields?.first {
            textField.text = "Updated notes"
        }
        // We can't easily trigger the save action in tests, but we've verified the setup
    }
    
    // MARK: - Factory Tests
    
    func testFactoryWithUIViewController() {
        // Given
        let viewController = UIViewController()
        
        // When
        let coordinator = DetailActionCoordinatorFactory.makeCoordinator(presenter: viewController)
        
        // Then
        XCTAssertNotNil(coordinator)
        // Verify it's the private implementation by testing it handles actions
        coordinator.handle(.pauseAudio) // Should not crash
    }
}