//
//  DetailViewModel.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

// MARK: - ImageColors

struct ImageColors {
    let backgroundColor: Color
    let primaryColor: Color
    let secondaryColor: Color
    let detailColor: Color
    
    init(_ brcColors: BRCImageColors) {
        self.backgroundColor = Color(brcColors.backgroundColor)
        self.primaryColor = Color(brcColors.primaryColor)
        self.secondaryColor = Color(brcColors.secondaryColor)
        self.detailColor = Color(brcColors.detailColor)
    }
}

class DetailViewModel: ObservableObject {
    // MARK: - Published State
    @Published var dataObject: BRCDataObject
    @Published var metadata: BRCObjectMetadata
    @Published var cells: [DetailCell] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAudioPlaying = false
    @Published var selectedImage: UIImage?
    
    // MARK: - Dependencies
    private let dataService: DetailDataServiceProtocol
    private let audioService: AudioServiceProtocol
    private let locationService: LocationServiceProtocol
    private let coordinator: DetailActionCoordinator
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        coordinator: DetailActionCoordinator
    ) {
        self.dataObject = dataObject
        self.dataService = dataService
        self.audioService = audioService
        self.locationService = locationService
        self.coordinator = coordinator
        
        // Initialize with basic metadata - no side effects in init
        self.metadata = dataService.getMetadata(for: dataObject) ?? BRCObjectMetadata()
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Update metadata
        if let updatedMetadata = dataService.getMetadata(for: dataObject) {
            self.metadata = updatedMetadata
        }
        
        // Generate cells
        self.cells = generateCells()
    }
    
    @MainActor
    func toggleFavorite() async {
        let newFavoriteStatus = !metadata.isFavorite
        
        do {
            try await dataService.updateFavoriteStatus(for: dataObject, isFavorite: newFavoriteStatus)
            
            // Update local state
            self.metadata.isFavorite = newFavoriteStatus
            
            // Regenerate cells to reflect changes
            self.cells = generateCells()
            
        } catch {
            self.error = error
        }
    }
    
    @MainActor
    func updateNotes(_ notes: String) async {
        do {
            try await dataService.updateUserNotes(for: dataObject, notes: notes)
            
            // Update local state
            self.metadata.userNotes = notes
            
            // Regenerate cells to reflect changes
            self.cells = generateCells()
            
        } catch {
            self.error = error
        }
    }
    
    func handleCellTap(_ cell: DetailCell) {
        switch cell.type {
        case .email(let email, _):
            coordinator.handle(.openEmail(email))
            
        case .url(let url, _):
            coordinator.handle(.openURL(url))
            
        case .coordinates(let coordinate, _):
            coordinator.handle(.shareCoordinates(coordinate))
            
        case .relationship(let object, _):
            coordinator.handle(.navigateToObject(object))
            
        case .eventRelationship(let events, let hostName):
            coordinator.handle(.showEventsList(events, hostName: hostName))
            
        case .nextHostEvent(let nextEvent, _):
            coordinator.handle(.showNextEvent(nextEvent))
            
        case .allHostEvents(_, let hostName):
            // Get all events for this host and show them
            if let eventObject = dataObject as? BRCEventObject {
                let hostId = eventObject.hostedByCampUniqueID ?? eventObject.hostedByArtUniqueID
                if let hostId = hostId {
                    var allEvents: [BRCEventObject] = []
                    if let camp = dataService.getCamp(withId: hostId) {
                        allEvents = dataService.getEvents(for: camp) ?? []
                    } else if let art = dataService.getArt(withId: hostId) {
                        allEvents = dataService.getEvents(for: art) ?? []
                    }
                    coordinator.handle(.showEventsList(allEvents, hostName: hostName))
                }
            }
            
        case .playaAddress(_, let tappable):
            if tappable {
                coordinator.handle(.showMap(dataObject))
            }
            
        case .image(let image, _):
            selectedImage = image
            
        case .mapView(let dataObject, _):
            coordinator.handle(.showMap(dataObject))
            
        case .audio(let artObject, _):
            if audioService.isPlaying(artObject: artObject) {
                audioService.pauseAudio()
                isAudioPlaying = false
            } else {
                audioService.playAudio(artObjects: [artObject])
                isAudioPlaying = true
            }
            
        case .userNotes(let currentNotes):
            coordinator.handle(.editNotes(current: currentNotes) { [weak self] newNotes in
                Task { @MainActor in
                    await self?.updateNotes(newNotes)
                }
            })
            
        default:
            // Non-interactive cells
            break
        }
    }
    
    func showEventEditor() {
        if let eventObject = dataObject as? BRCEventObject {
            coordinator.handle(.showEventEditor(eventObject))
        }
    }
    
    /// Extract theme colors following the same logic as BRCDetailViewController
    func getThemeColors() -> ImageColors {
        // If image colors theming is disabled, always return global theme colors
        if !Appearance.useImageColorsTheming {
            return ImageColors(Appearance.currentColors)
        }
        
        // Special handling for events - try to get colors from hosting camp first
        if let eventObject = dataObject as? BRCEventObject {
            return getEventThemeColors(for: eventObject)
        }
        
        // For Art/Camp objects, check if metadata has thumbnail colors
        if let artMetadata = metadata as? BRCArtMetadata,
           let imageColors = artMetadata.thumbnailImageColors {
            return ImageColors(imageColors)
        } else if let campMetadata = metadata as? BRCCampMetadata,
                  let imageColors = campMetadata.thumbnailImageColors {
            return ImageColors(imageColors)
        }
        
        // Fallback to global theme colors
        return ImageColors(Appearance.currentColors)
    }
    
    /// Handle event-specific color logic - try hosting camp colors first
    private func getEventThemeColors(for event: BRCEventObject) -> ImageColors {
        // Try to get colors from hosting camp's image first
        if let campId = event.hostedByCampUniqueID,
           let camp = dataService.getCamp(withId: campId) {
            
            // Get camp metadata and check for image colors
            if let campMetadata = dataService.getMetadata(for: camp) as? BRCCampMetadata,
               let campImageColors = campMetadata.thumbnailImageColors {
                return ImageColors(campImageColors)
            }
        }
        
        // Fallback to event type colors
        return ImageColors(BRCImageColors.colors(for: event.eventType))
    }
    
    // MARK: - Private Methods
    
    private func generateCells() -> [DetailCell] {
        let cellTypes = generateCellTypes()
        return cellTypes.map { DetailCell($0) }
    }
    
    private func generateCellTypes() -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        
        // Add image header first if available (for all object types)
        if let artObject = dataObject as? BRCArtObject,
           let imageURL = artObject.localThumbnailURL,
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
        }
        // Add camp image for camp objects
        else if let campObject = dataObject as? BRCCampObject,
           let imageURL = campObject.localThumbnailURL,
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
        }
        // Add host image for event objects (camp or art)
        else if let eventObject = dataObject as? BRCEventObject {
            if let campImage = loadHostCampImage(for: eventObject) {
                let aspectRatio = campImage.size.width / campImage.size.height
                cellTypes.append(.image(campImage, aspectRatio: aspectRatio))
            } else if let artImage = loadHostArtImage(for: eventObject) {
                let aspectRatio = artImage.size.width / artImage.size.height
                cellTypes.append(.image(artImage, aspectRatio: aspectRatio))
            }
        }
        
        // Add map view if object has location and is not embargoed
        if shouldShowMap() {
            cellTypes.append(.mapView(dataObject, metadata: metadata))
        }
        
        // Add title
        let title = dataObject.title
        if !title.isEmpty {
            cellTypes.append(.text(title, style: .title))
        }
        
        // Add description
        if let description = dataObject.detailDescription, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }
        
        // Add type-specific cells
        if let artObject = dataObject as? BRCArtObject {
            cellTypes.append(contentsOf: generateArtCells(artObject))
        } else if let campObject = dataObject as? BRCCampObject {
            cellTypes.append(contentsOf: generateCampCells(campObject))
        } else if let eventObject = dataObject as? BRCEventObject {
            cellTypes.append(contentsOf: generateEventCells(eventObject))
        }
        
        // Add common cells
        cellTypes.append(contentsOf: generateCommonCells())
        
        // Add host images for camps and events (after user notes, before metadata)
        cellTypes.append(contentsOf: generateHostImageCells())
        
        // Add metadata section at the end
        cellTypes.append(contentsOf: generateMetadataCells())
        
        return cellTypes
    }
    
    private func generateArtCells(_ art: BRCArtObject) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Artist name
        let artistName = art.artistName
        if !artistName.isEmpty {
            cells.append(.text("Artist: \(artistName)", style: .subtitle))
        }
        
        // Artist location
        let artistLocation = art.artistLocation
        if !artistLocation.isEmpty {
            cells.append(.text("Artist Location: \(artistLocation)", style: .caption))
        }
        
        // Audio tour
        if art.audioURL != nil {
            let isPlaying = audioService.isPlaying(artObject: art)
            cells.append(.audio(art, isPlaying: isPlaying))
        }
        
        // Next event
        if let nextEvent = dataService.getNextEvent(for: art) {
            cells.append(.nextHostEvent(nextEvent, hostName: art.title))
        }
        
        // Hosted events
        if let events = dataService.getEvents(for: art), !events.isEmpty {
            cells.append(.eventRelationship(events, hostName: art.title))
        }
        
        return cells
    }
    
    private func generateCampCells(_ camp: BRCCampObject) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Hometown
        if let hometown = camp.hometown, !hometown.isEmpty {
            cells.append(.text("Hometown: \(hometown)", style: .caption))
        }
        
        // Next event
        if let nextEvent = dataService.getNextEvent(for: camp) {
            cells.append(.nextHostEvent(nextEvent, hostName: camp.title))
        }
        
        // Hosted events
        if let events = dataService.getEvents(for: camp), !events.isEmpty {
            cells.append(.eventRelationship(events, hostName: camp.title))
        }
        
        return cells
    }
    
    private func generateEventCells(_ event: BRCEventObject) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Host relationship (camp or art)
        var hostName: String?
        var hostId: String?
        
        if let campId = event.hostedByCampUniqueID,
           let camp = dataService.getCamp(withId: campId) {
            cells.append(.relationship(camp, type: .hostedBy(camp.title)))
            hostName = camp.title
            hostId = campId
        } else if let artId = event.hostedByArtUniqueID,
                  let art = dataService.getArt(withId: artId) {
            cells.append(.relationship(art, type: .hostedBy(art.title)))
            hostName = art.title
            hostId = artId
        }
        
        // Next event and all events from the same host
        if let hostId = hostId, let hostName = hostName {
            // Get next event from the same host
            if let nextEvent = dataService.getNextEvent(forHostId: hostId, after: event) {
                cells.append(.nextHostEvent(nextEvent, hostName: hostName))
            }
            
            // Get count of other events and show "see all" if more than just next event
            let otherEventsCount = dataService.getOtherEventsCount(forHostId: hostId, excluding: event)
            if otherEventsCount > 0 {
                cells.append(.allHostEvents(count: otherEventsCount, hostName: hostName))
            }
        }
        
        // Schedule information with proper formatting
        if let startDate = event.startDate as Date?,
           let endDate = event.endDate as Date? {
            let scheduleString = formatEventSchedule(event: event, startDate: startDate, endDate: endDate)
            cells.append(.schedule(scheduleString))
        }
        
        // Location with embargo handling
        let locationValue = getLocationValue(for: event)
        cells.append(.playaAddress(locationValue, tappable: dataService.canShowLocation(for: event)))
        
        // Add host description if available
        if let hostDescription = getHostDescription(for: event) {
            cells.append(.text(hostDescription, style: .body))
        }
        
        return cells
    }
    
    private func formatEventSchedule(event: BRCEventObject, startDate: Date, endDate: Date) -> NSAttributedString {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE M/d"
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let dayString = dayFormatter.string(from: startDate)
        var timeString: String
        
        if event.isAllDay {
            timeString = "All Day"
        } else {
            let start = timeFormatter.string(from: startDate)
            let end = timeFormatter.string(from: endDate)
            timeString = "\(start) - \(end)"
        }
        
        let fullString = "\(dayString)\n\(timeString)"
        let attributedString = NSMutableAttributedString(string: fullString)
        
        // Color the time portion based on event status
        let timeColor = getEventTimeColor(for: event, startDate: startDate, endDate: endDate)
        let timeRange = NSRange(location: dayString.count + 1, length: timeString.count)
        attributedString.addAttribute(.foregroundColor, value: timeColor, range: timeRange)
        
        return attributedString
    }
    
    private func getEventTimeColor(for event: BRCEventObject, startDate: Date, endDate: Date) -> UIColor {
        let now = Date()
        if now < startDate {
            return .systemGreen // Future event
        } else if now >= startDate && now <= endDate {
            return .systemOrange // Current event
        } else {
            return .systemRed // Past event
        }
    }
    
    private func getLocationValue(for object: BRCDataObject) -> String {
        if !dataService.canShowLocation(for: object) {
            return "Restricted"
        }
        
        // Special handling for events - prioritize host location
        if let event = object as? BRCEventObject {
            // Try camp host location first
            if let campId = event.hostedByCampUniqueID,
               let camp = dataService.getCamp(withId: campId),
               let campLocation = camp.playaLocation, !campLocation.isEmpty {
                return campLocation
            }
            // Try art host location
            else if let artId = event.hostedByArtUniqueID,
                    let art = dataService.getArt(withId: artId),
                    let artLocation = art.playaLocation, !artLocation.isEmpty {
                return artLocation
            }
        }
        
        // Default to object's own location
        if let location = object.playaLocation, !location.isEmpty {
            return location
        } else {
            return "Unknown"
        }
    }
    
    private func getHostDescription(for event: BRCEventObject) -> String? {
        if let campId = event.hostedByCampUniqueID,
           let camp = dataService.getCamp(withId: campId),
           let description = camp.detailDescription,
           !description.isEmpty {
            return description
        } else if let artId = event.hostedByArtUniqueID,
                  let art = dataService.getArt(withId: artId),
                  let description = art.detailDescription,
                  !description.isEmpty {
            return description
        }
        return nil
    }
    
    private func generateHostImageCells() -> [DetailCellType] {
        let cells: [DetailCellType] = []
        
        // Image generation moved to top of generateCellTypes()
        // This method reserved for any future host-related cells that aren't images
        
        return cells
    }
    
    private func generateCommonCells() -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Email
        if let email = dataObject.email, !email.isEmpty {
            cells.append(.email(email, label: "Contact"))
        }
        
        // URL
        if let url = dataObject.url {
            cells.append(.url(url, title: "Website"))
        }
        
        // GPS coordinates - only show if embargo allows
        if dataService.canShowLocation(for: dataObject), let location = dataObject.location {
            cells.append(.coordinates(location.coordinate, label: "GPS Coordinates"))
        }
        
        // Distance
        if let distance = locationService.distanceToObject(dataObject) {
            cells.append(.distance(distance))
        }
        
        // User notes
        let notes = metadata.userNotes ?? ""
        cells.append(.userNotes(notes))
        
        return cells
    }
    
    private func generateMetadataCells() -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Last updated
        if let updateDate = metadata.lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let dateString = formatter.string(from: updateDate)
            cells.append(.text("Last Updated: \(dateString)", style: .caption))
        }
        
        return cells
    }
    
    private func loadImage(from url: URL) -> UIImage? {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        // Load image from disk
        return UIImage(contentsOfFile: url.path)
    }
    
    private func loadHostCampImage(for event: BRCEventObject) -> UIImage? {
        guard let campId = event.hostedByCampUniqueID else { return nil }
        
        // Get camp from database
        if let camp = dataService.getCamp(withId: campId),
           let imageURL = camp.localThumbnailURL {
            return loadImage(from: imageURL)
        }
        
        return nil
    }
    
    private func loadHostArtImage(for event: BRCEventObject) -> UIImage? {
        guard let artId = event.hostedByArtUniqueID else { return nil }
        
        // Get art from database
        if let art = dataService.getArt(withId: artId),
           let imageURL = art.localThumbnailURL {
            return loadImage(from: imageURL)
        }
        
        return nil
    }
    
    /// Determines if map should be shown based on location and embargo status
    /// Following the same logic as BRCDetailViewController.setupMapViewWithObject:
    private func shouldShowMap() -> Bool {
        // Check if object has location data and embargo allows showing it
        if let _ = dataObject.location, BRCEmbargo.canShowLocation(for: dataObject) {
            return true
        }
        
        // Also check for burner map location (user-set location)
        if let _ = dataObject.burnerMapLocation {
            return true
        }
        
        return false
    }
}
