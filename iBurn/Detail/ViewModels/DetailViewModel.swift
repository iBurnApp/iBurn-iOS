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
import PlayaDB

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

@MainActor
class DetailViewModel: ObservableObject {
    // MARK: - Published State
    @Published var subject: DetailSubject
    @Published var legacyMetadata: BRCObjectMetadata?
    @Published var isFavorite: Bool
    @Published var userNotes: String
    @Published var extractedImageColors: BRCImageColors?
    @Published var cells: [DetailCell] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAudioPlaying = false
    @Published var selectedImage: UIImage?
    
    // MARK: - Dependencies
    private let dataService: DetailDataServiceProtocol?
    private let playaDB: PlayaDB?
    private let mediaProvider: MediaAssetProviding

    private let audioService: AudioServiceProtocol?
    private let audioPlayer: any AudioPlayerProtocol
    private let locationService: LocationServiceProtocol
    private let coordinator: DetailActionCoordinator

    private let rowAssets: RowAssetsLoader?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var audioNotificationObserver: NSObjectProtocol?
    
    // MARK: - Initialization

    /// Backwards-compatible initializer for legacy YapDB-backed detail screens.
    init(
        dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        coordinator: DetailActionCoordinator
    ) {
        let mediaProvider = BRCMediaAssetProvider()
        let rowAssets: RowAssetsLoader?
        if dataObject is BRCArtObject || dataObject is BRCCampObject {
            rowAssets = RowAssetsLoader(objectID: dataObject.uniqueID, provider: mediaProvider)
        } else {
            rowAssets = nil
        }

        self.subject = .legacy(dataObject)
        self.dataService = dataService
        self.playaDB = nil
        self.mediaProvider = mediaProvider
        self.audioService = audioService
        self.audioPlayer = BRCAudioPlayer.sharedInstance
        self.locationService = locationService
        self.coordinator = coordinator
        self.rowAssets = rowAssets

        let md = dataService.getMetadata(for: dataObject) ?? BRCObjectMetadata()
        self.legacyMetadata = md
        self.isFavorite = md.isFavorite
        self.userNotes = md.userNotes ?? ""
        self.extractedImageColors = rowAssets?.colors

        rowAssets?.$colors
            .sink { [weak self] colors in
                self?.extractedImageColors = colors
            }
            .store(in: &cancellables)

        setupAudioNotificationObserver()
    }

    /// PlayaDB-backed initializer.
    init(
        object: any PlayaDB.DataObject,
        playaDB: PlayaDB,
        locationService: LocationServiceProtocol,
        coordinator: DetailActionCoordinator,
        mediaProvider: MediaAssetProviding = BRCMediaAssetProvider(),
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance
    ) {
        let rowAssets: RowAssetsLoader?
        if object.objectType == .art || object.objectType == .camp {
            rowAssets = RowAssetsLoader(objectID: object.uid, provider: mediaProvider)
        } else {
            rowAssets = nil
        }

        self.subject = .playa(object)
        self.dataService = nil
        self.playaDB = playaDB
        self.mediaProvider = mediaProvider
        self.audioService = nil
        self.audioPlayer = audioPlayer
        self.locationService = locationService
        self.coordinator = coordinator
        self.rowAssets = rowAssets

        self.legacyMetadata = nil
        self.isFavorite = false
        self.userNotes = ""
        self.extractedImageColors = rowAssets?.colors

        rowAssets?.$colors
            .sink { [weak self] colors in
                self?.extractedImageColors = colors
            }
            .store(in: &cancellables)

        setupAudioNotificationObserver()
    }
    
    deinit {
        // Clean up notification observer
        if let observer = audioNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var title: String { subject.title }

    var showsCalendarButton: Bool {
        if case .legacy(let obj) = subject, obj is BRCEventObject { return true }
        return false
    }
    
    // MARK: - Public Methods
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        switch subject {
        case .legacy(let obj):
            guard let dataService else { break }

            if let updated = dataService.getMetadata(for: obj) {
                legacyMetadata = updated
                isFavorite = updated.isFavorite
                userNotes = updated.userNotes ?? ""
            }

            if let artObject = obj as? BRCArtObject, artObject.audioURL != nil {
                isAudioPlaying = audioService?.isPlaying(artObject: artObject) ?? false
            }

        case .playa(let obj):
            guard let playaDB else { break }
            do {
                let md = try await playaDB.metadata(for: obj)
                isFavorite = md.isFavorite
                userNotes = md.userNotes ?? ""
                try await playaDB.setLastViewed(Date(), for: obj)
            } catch {
                self.error = error
            }

            if localAudioURL(objectID: obj.uid) != nil {
                isAudioPlaying = audioPlayer.isPlaying(id: obj.uid)
            }
        }

        rowAssets?.startIfNeeded()
        self.cells = generateCells()
    }
    
    func toggleFavorite() async {
        let newFavoriteStatus = !isFavorite
        
        do {
            switch subject {
            case .legacy(let obj):
                guard let dataService else { throw DetailError.invalidData }
                try await dataService.updateFavoriteStatus(for: obj, isFavorite: newFavoriteStatus)
                legacyMetadata?.isFavorite = newFavoriteStatus
                isFavorite = newFavoriteStatus
            case .playa(let obj):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.toggleFavorite(obj)
                isFavorite = try await playaDB.isFavorite(obj)
            }

            self.cells = generateCells()
            
        } catch {
            self.error = error
        }
    }
    
    func updateNotes(_ notes: String) async {
        do {
            switch subject {
            case .legacy(let obj):
                guard let dataService else { throw DetailError.invalidData }
                try await dataService.updateUserNotes(for: obj, notes: notes)
                legacyMetadata?.userNotes = notes
                userNotes = notes
            case .playa(let obj):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: obj)
                userNotes = notes
            }

            self.cells = generateCells()
            
        } catch {
            self.error = error
        }
    }
    
    func updateVisitStatus(_ status: BRCVisitStatus) async {
        do {
            guard case .legacy(let obj) = subject, let dataService else {
                return
            }
            try await dataService.updateVisitStatus(for: obj, visitStatus: status)
            legacyMetadata?.visitStatus = status.rawValue
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
            guard case .legacy(let legacyObject) = subject,
                  let eventObject = legacyObject as? BRCEventObject,
                  let dataService else {
                break
            }
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
            
        case .playaAddress(_, let tappable):
            if tappable {
                switch subject {
                case .legacy(let legacyObject):
                    coordinator.handle(.showMap(legacyObject))
                case .playa(let obj):
                    if let annotation = playaAnnotation(for: obj) {
                        coordinator.handle(.showMapAnnotation(annotation, title: "Map - \(obj.name)"))
                    }
                }
            }
            
        case .image(let image, _):
            selectedImage = image
            
        case .mapView(let dataObject, _):
            coordinator.handle(.showMap(dataObject))

        case .mapAnnotation(let annotation, let title):
            coordinator.handle(.showMapAnnotation(annotation, title: title))
            
        case .audio(let artObject, _):
            guard let audioService else { break }
            if audioService.isPlaying(artObject: artObject) {
                audioService.pauseAudio()
            } else {
                audioService.playAudio(artObjects: [artObject])
            }
            // Audio state will be updated via notification observer

        case .audioTrack(let track, _):
            audioPlayer.playAudioTour([track])
            isAudioPlaying = audioPlayer.isPlaying(id: track.uid)
            cells = generateCells()
            
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
        if case .legacy(let legacyObject) = subject, let eventObject = legacyObject as? BRCEventObject {
            coordinator.handle(.showEventEditor(eventObject))
        }
    }
    
    func shareObject() {
        switch subject {
        case .legacy(let legacyObject):
            // Show QR code share screen instead of direct share sheet
            coordinator.handle(.showShareScreen(legacyObject))
        case .playa(let obj):
            let text = "\(obj.objectType.displayName): \(obj.name)\nID: \(obj.uid)"
            coordinator.handle(.share([text]))
        }
    }
    
    /// Extract theme colors following the same logic as BRCDetailViewController
    func getThemeColors() -> ImageColors {
        // If image colors theming is disabled, always return global theme colors
        if !Appearance.useImageColorsTheming {
            return ImageColors(Appearance.currentColors)
        }

        switch subject {
        case .legacy(let legacyObject):
            // Special handling for events - try to get colors from hosting camp first
            if let eventObject = legacyObject as? BRCEventObject {
                return getEventThemeColors(for: eventObject)
            }

            // For Art/Camp objects, check if metadata has thumbnail colors
            if let artMetadata = legacyMetadata as? BRCArtMetadata,
               let imageColors = artMetadata.thumbnailImageColors {
                return ImageColors(imageColors)
            } else if let campMetadata = legacyMetadata as? BRCCampMetadata,
                      let imageColors = campMetadata.thumbnailImageColors {
                return ImageColors(imageColors)
            }

            return ImageColors(Appearance.currentColors)

        case .playa:
            if let colors = extractedImageColors {
                return ImageColors(colors)
            }
            return ImageColors(Appearance.currentColors)
        }
    }
    
    // MARK: - Audio State Management
    
    private func setupAudioNotificationObserver() {
        audioNotificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(BRCAudioPlayer.BRCAudioPlayerChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAudioPlayingState()
        }
    }
    
    private func updateAudioPlayingState() {
        let wasPlaying = isAudioPlaying

        switch subject {
        case .legacy(let legacyObject):
            guard let artObject = legacyObject as? BRCArtObject,
                  artObject.audioURL != nil else {
                return
            }
            isAudioPlaying = audioService?.isPlaying(artObject: artObject) ?? false

        case .playa(let obj):
            guard localAudioURL(objectID: obj.uid) != nil else { return }
            isAudioPlaying = audioPlayer.isPlaying(id: obj.uid)
        }

        if wasPlaying != isAudioPlaying {
            cells = generateCells()
        }
    }
    
    /// Handle event-specific color logic - try hosting camp colors first
    private func getEventThemeColors(for event: BRCEventObject) -> ImageColors {
        // Try to get colors from hosting camp's image first
        if let campId = event.hostedByCampUniqueID,
           let dataService,
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
        switch subject {
        case .legacy(let legacyObject):
            guard let dataService else { return [] }
            let md = legacyMetadata ?? BRCObjectMetadata()
            return generateLegacyCellTypes(legacyObject, metadata: md, dataService: dataService)

        case .playa(let obj):
            return generatePlayaCellTypes(obj)
        }
    }

    private func generateLegacyCellTypes(
        _ dataObject: BRCDataObject,
        metadata: BRCObjectMetadata,
        dataService: DetailDataServiceProtocol
    ) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        var hasImage = false

        // Add image header first if available (for all object types)
        if let artObject = dataObject as? BRCArtObject,
           let imageURL = artObject.localThumbnailURL,
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
            hasImage = true
        }
        // Add camp image for camp objects
        else if let campObject = dataObject as? BRCCampObject,
                let imageURL = campObject.localThumbnailURL,
                let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
            hasImage = true
        }
        // Add host image for event objects (camp or art)
        else if let eventObject = dataObject as? BRCEventObject {
            if let campImage = loadHostCampImage(for: eventObject, dataService: dataService) {
                let aspectRatio = campImage.size.width / campImage.size.height
                cellTypes.append(.image(campImage, aspectRatio: aspectRatio))
                hasImage = true
            } else if let artImage = loadHostArtImage(for: eventObject, dataService: dataService) {
                let aspectRatio = artImage.size.width / artImage.size.height
                cellTypes.append(.image(artImage, aspectRatio: aspectRatio))
                hasImage = true
            }
        }

        // Add map view if object has location and is not embargoed
        // Only add here if no image exists, otherwise add it later before GPS coordinates
        if shouldShowMap(dataObject) && !hasImage {
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
            cellTypes.append(contentsOf: generateArtCells(artObject, dataService: dataService))
        } else if let campObject = dataObject as? BRCCampObject {
            cellTypes.append(contentsOf: generateCampCells(campObject, dataService: dataService))
        } else if let eventObject = dataObject as? BRCEventObject {
            cellTypes.append(contentsOf: generateEventCells(eventObject, dataService: dataService))
        }

        // Add common cells
        cellTypes.append(contentsOf: generateLegacyCommonCells(dataObject: dataObject, metadata: metadata, dataService: dataService, hasImage: hasImage))

        // Add metadata section at the end
        cellTypes.append(contentsOf: generateLegacyMetadataCells(metadata))

        return cellTypes
    }

    private func generatePlayaCellTypes(_ object: any PlayaDB.DataObject) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        var hasImage = false

        if let imageURL = localThumbnailURL(objectID: object.uid),
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
            hasImage = true
        }

        let canShowLocation = BRCEmbargo.allowEmbargoedData()
        if canShowLocation, let annotation = playaAnnotation(for: object), !hasImage {
            cellTypes.append(.mapAnnotation(annotation, title: "Map - \(object.name)"))
        }

        cellTypes.append(.text(object.name, style: .title))

        if let description = object.description, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }

        // Type-specific bits
        if let art = object as? ArtObject {
            if let artist = art.artist, !artist.isEmpty {
                cellTypes.append(.text("Artist: \(artist)", style: .subtitle))
            }
        } else if let camp = object as? CampObject {
            if let hometown = camp.hometown, !hometown.isEmpty {
                cellTypes.append(.text("Hometown: \(hometown)", style: .caption))
            }
            if let landmark = camp.landmark, !landmark.isEmpty {
                cellTypes.append(.landmark(landmark))
            }
        }

        // Location with embargo handling
        let locationValue: String
        if canShowLocation {
            locationValue = object.location != nil ? (subject.locationString ?? "Unknown") : "Unknown"
        } else {
            locationValue = "Restricted"
        }
        cellTypes.append(.playaAddress(locationValue, tappable: canShowLocation && object.location != nil))

        // Media-driven audio tour
        if let audioURL = localAudioURL(objectID: object.uid),
           let track = makeAudioTrack(objectID: object.uid, title: object.name, artist: (object as? ArtObject)?.artist, audioURL: audioURL) {
            cellTypes.append(.audioTrack(track, isPlaying: isAudioPlaying))
        }

        // Email / URL
        if let art = object as? ArtObject, let email = art.contactEmail, !email.isEmpty {
            cellTypes.append(.email(email, label: "Contact"))
        } else if let camp = object as? CampObject, let email = camp.contactEmail, !email.isEmpty {
            cellTypes.append(.email(email, label: "Contact"))
        }
        if let art = object as? ArtObject, let url = art.url {
            cellTypes.append(.url(url, title: "Website"))
        } else if let camp = object as? CampObject, let url = camp.url {
            cellTypes.append(.url(url, title: "Website"))
        }

        // Map preview before coordinates if we have a header image
        if canShowLocation, let annotation = playaAnnotation(for: object), hasImage {
            cellTypes.append(.mapAnnotation(annotation, title: "Map - \(object.name)"))
        }

        // GPS coordinates
        if canShowLocation, let location = object.location {
            cellTypes.append(.coordinates(location.coordinate, label: "GPS Coordinates"))
        }

        // Distance / travel time
        if canShowLocation, let distance = distanceToLocation(object.location) {
            cellTypes.append(.distance(distance))
            cellTypes.append(.travelTime(distance))
        }

        // Notes (stored in PlayaDB metadata)
        cellTypes.append(.userNotes(userNotes))

        return cellTypes
    }
    
    private func generateArtCells(_ art: BRCArtObject, dataService: DetailDataServiceProtocol) -> [DetailCellType] {
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
        
        // Location with embargo handling
        let locationValue = getLocationValue(for: art, dataService: dataService)
        cells.append(.playaAddress(locationValue, tappable: dataService.canShowLocation(for: art)))
        
        // Audio tour
        if art.audioURL != nil {
            cells.append(.audio(art, isPlaying: isAudioPlaying))
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
    
    private func generateCampCells(_ camp: BRCCampObject, dataService: DetailDataServiceProtocol) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Hometown
        if let hometown = camp.hometown, !hometown.isEmpty {
            cells.append(.text("Hometown: \(hometown)", style: .caption))
        }
        
        // Landmark
        if let landmark = camp.landmark, !landmark.isEmpty {
            cells.append(.landmark(landmark))
        }
        
        // Location with embargo handling
        let locationValue = getLocationValue(for: camp, dataService: dataService)
        cells.append(.playaAddress(locationValue, tappable: dataService.canShowLocation(for: camp)))
        
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
    
    private func generateEventCells(_ event: BRCEventObject, dataService: DetailDataServiceProtocol) -> [DetailCellType] {
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
        let locationValue = getLocationValue(for: event, dataService: dataService)
        cells.append(.playaAddress(locationValue, tappable: dataService.canShowLocation(for: event)))
        
        // Event type section
        cells.append(.eventType(event.eventType))
        
        // Add host description if available
        if let hostDescription = getHostDescription(for: event) {
            cells.append(.text(hostDescription, style: .body))
        }
        
        return cells
    }
    
    private func formatEventSchedule(event: BRCEventObject, startDate: Date, endDate: Date) -> NSAttributedString {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE M/d"
        dayFormatter.timeZone = TimeZone.burningManTimeZone
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = TimeZone.burningManTimeZone
        
        let dayString = dayFormatter.string(from: startDate)
        var timeString: String
        
        if event.isAllDay {
            let start = timeFormatter.string(from: startDate)
            let end = timeFormatter.string(from: endDate)
            timeString = "All Day (\(start) - \(end))"
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
    
    private func getLocationValue(for object: BRCDataObject, dataService: DetailDataServiceProtocol) -> String {
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
    
    private func generateLegacyCommonCells(
        dataObject: BRCDataObject,
        metadata: BRCObjectMetadata,
        dataService: DetailDataServiceProtocol,
        hasImage: Bool
    ) -> [DetailCellType] {
        var cells: [DetailCellType] = []

        // Email
        if let email = dataObject.email, !email.isEmpty {
            cells.append(.email(email, label: "Contact"))
        }

        // URL
        if let url = dataObject.url {
            cells.append(.url(url, title: "Website"))
        }

        // Add map view here if image exists (so it appears above GPS coordinates)
        if shouldShowMap(dataObject) && hasImage {
            cells.append(.mapView(dataObject, metadata: metadata))
        }

        // GPS coordinates - only show if embargo allows
        if dataService.canShowLocation(for: dataObject), let location = dataObject.location {
            cells.append(.coordinates(location.coordinate, label: "GPS Coordinates"))
        }

        // Distance
        if let distance = locationService.distanceToObject(dataObject) {
            cells.append(.distance(distance))
            cells.append(.travelTime(distance))
        }

        // User notes
        cells.append(.userNotes(userNotes))

        // Visit status
        let visitStatus = BRCVisitStatus(rawValue: metadata.visitStatus) ?? .unvisited
        cells.append(.visitStatus(visitStatus))

        return cells
    }

    private func generateLegacyMetadataCells(_ metadata: BRCObjectMetadata) -> [DetailCellType] {
        var cells: [DetailCellType] = []

        if let updateDate = metadata.lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.timeZone = TimeZone.burningManTimeZone
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
    
    private func loadHostCampImage(for event: BRCEventObject, dataService: DetailDataServiceProtocol) -> UIImage? {
        guard let campId = event.hostedByCampUniqueID else { return nil }
        
        // Get camp from database
        if let camp = dataService.getCamp(withId: campId),
           let imageURL = camp.localThumbnailURL {
            return loadImage(from: imageURL)
        }
        
        return nil
    }
    
    private func loadHostArtImage(for event: BRCEventObject, dataService: DetailDataServiceProtocol) -> UIImage? {
        guard let artId = event.hostedByArtUniqueID else { return nil }
        
        // Get art from database
        if let art = dataService.getArt(withId: artId),
           let imageURL = art.localThumbnailURL {
            return loadImage(from: imageURL)
        }
        
        return nil
    }

    private func localThumbnailURL(objectID: String) -> URL? {
        mediaProvider.localThumbnailURL(objectID: objectID)
    }

    private func localAudioURL(objectID: String) -> URL? {
        mediaProvider.localAudioURL(objectID: objectID)
    }

    private func playaAnnotation(for object: any PlayaDB.DataObject) -> PlayaObjectAnnotation? {
        if let art = object as? ArtObject {
            return PlayaObjectAnnotation(art: art)
        }
        if let camp = object as? CampObject {
            return PlayaObjectAnnotation(camp: camp)
        }
        // Event annotations not supported yet (event occurrences are the map unit).
        return nil
    }

    private func makeAudioTrack(
        objectID: String,
        title: String,
        artist: String?,
        audioURL: URL
    ) -> BRCAudioTourTrack? {
        BRCAudioTourTrack(
            uid: objectID,
            title: title,
            artist: artist,
            audioURL: audioURL,
            artworkURL: localThumbnailURL(objectID: objectID)
        )
    }

    private func distanceToLocation(_ location: CLLocation?) -> CLLocationDistance? {
        guard let location, let current = locationService.getCurrentLocation() else { return nil }
        return current.distance(from: location)
    }
    
    /// Determines if map should be shown based on location and embargo status
    /// Following the same logic as BRCDetailViewController.setupMapViewWithObject:
    private func shouldShowMap(_ dataObject: BRCDataObject) -> Bool {
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
