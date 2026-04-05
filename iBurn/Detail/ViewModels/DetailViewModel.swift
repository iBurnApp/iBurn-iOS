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
    private var preloadedImages: [String: UIImage] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var audioNotificationObserver: NSObjectProtocol?
    /// Resolved host camp or art name for events (set during loadContent)
    private var resolvedHostName: String?
    /// Resolved host subject for navigation from event occurrence detail
    private var resolvedHostSubject: DetailSubject?
    /// Resolved host description text
    private var resolvedHostDescription: String?
    /// Resolved host location string
    private var resolvedHostLocation: String?
    /// Resolved events from the same host
    private var resolvedHostEvents: [EventObjectOccurrence] = []
    
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

        // `BRCObjectMetadata`'s default init comes from Mantle (Obj-C) and may be imported as optional.
        // In practice it should always succeed; force-unwrap so downstream APIs can keep using a
        // non-optional metadata object.
        let md = dataService.getMetadata(for: dataObject) ?? BRCObjectMetadata()!
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
        subject: DetailSubject,
        playaDB: PlayaDB,
        locationService: LocationServiceProtocol,
        coordinator: DetailActionCoordinator,
        mediaProvider: MediaAssetProviding = BRCMediaAssetProvider(),
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance
    ) {
        precondition(
            {
                if case .legacy = subject { return false }
                return true
            }(),
            "Use the legacy initializer for BRCDataObject"
        )

        let rowAssets: RowAssetsLoader?
        switch subject {
        case .art(let art):
            rowAssets = RowAssetsLoader(objectID: art.uid, provider: mediaProvider)
        case .camp(let camp):
            rowAssets = RowAssetsLoader(objectID: camp.uid, provider: mediaProvider)
        case .mutantVehicle(let mv):
            rowAssets = RowAssetsLoader(objectID: mv.uid, provider: mediaProvider)
        case .event, .eventOccurrence, .legacy:
            rowAssets = nil
        }

        self.subject = subject
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

        // Phase 1: Load essential metadata (fast) and show cells immediately
        await loadMetadata()
        isLoading = false
        self.cells = generateCells()

        // Phase 2: Load expensive data in background, then refresh cells
        await loadDeferredData()
    }

    /// Phase 1: Quick metadata queries to show content ASAP
    private func loadMetadata() async {
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

        case .art(let art):
            guard let playaDB else { break }
            do {
                let md = try await playaDB.metadata(for: art)
                isFavorite = md.isFavorite
                userNotes = md.userNotes ?? ""
            } catch {
                self.error = error
            }
            if localAudioURL(objectID: art.uid) != nil {
                isAudioPlaying = audioPlayer.isPlaying(id: art.uid)
            }

        case .camp(let camp):
            guard let playaDB else { break }
            do {
                let md = try await playaDB.metadata(for: camp)
                isFavorite = md.isFavorite
                userNotes = md.userNotes ?? ""
            } catch {
                self.error = error
            }

        case .event(let event):
            guard let playaDB else { break }
            do {
                let md = try await playaDB.metadata(for: event)
                isFavorite = md.isFavorite
                userNotes = md.userNotes ?? ""
            } catch {
                self.error = error
            }

        case .eventOccurrence(let occ):
            guard let playaDB else { break }
            do {
                let md = try await playaDB.metadata(for: occ)
                isFavorite = md.isFavorite
                userNotes = md.userNotes ?? ""
            } catch {
                self.error = error
            }

        case .mutantVehicle(let mv):
            guard let playaDB else { break }
            do {
                let md = try await playaDB.metadata(for: mv)
                isFavorite = md.isFavorite
                userNotes = md.userNotes ?? ""
            } catch {
                self.error = error
            }
        }
    }

    /// Phase 2: Expensive work (images, hosted events, setLastViewed) then refresh
    private func loadDeferredData() async {
        var needsRefresh = false

        // Preload images off main thread
        await preloadImages()
        needsRefresh = !preloadedImages.isEmpty

        switch subject {
        case .legacy:
            break

        case .art(let art):
            guard let playaDB else { break }
            try? await playaDB.setLastViewed(Date(), for: art)
            let events = (try? await playaDB.fetchEvents(locatedAtArtUID: art.uid)) ?? []
            if !events.isEmpty {
                resolvedHostEvents = events
                needsRefresh = true
            }

        case .camp(let camp):
            guard let playaDB else { break }
            try? await playaDB.setLastViewed(Date(), for: camp)
            let events = (try? await playaDB.fetchEvents(hostedByCampUID: camp.uid)) ?? []
            if !events.isEmpty {
                resolvedHostEvents = events
                needsRefresh = true
            }

        case .event(let event):
            guard let playaDB else { break }
            try? await playaDB.setLastViewed(Date(), for: event)
            if let campUID = event.hostedByCamp {
                resolvedHostName = try? await playaDB.fetchCamp(uid: campUID)?.name
                needsRefresh = true
            } else if let artUID = event.locatedAtArt {
                resolvedHostName = try? await playaDB.fetchArt(uid: artUID)?.name
                needsRefresh = true
            }

        case .eventOccurrence(let occ):
            guard let playaDB else { break }
            try? await playaDB.setLastViewed(Date(), for: occ)
            if let campUID = occ.hostedByCamp,
               let camp = try? await playaDB.fetchCamp(uid: campUID) {
                resolvedHostName = camp.name
                resolvedHostSubject = .camp(camp)
                resolvedHostDescription = camp.description
                resolvedHostLocation = camp.locationString ?? camp.intersection
                resolvedHostEvents = (try? await playaDB.fetchEvents(hostedByCampUID: campUID)) ?? []
                needsRefresh = true
            } else if let artUID = occ.locatedAtArt,
                      let art = try? await playaDB.fetchArt(uid: artUID) {
                resolvedHostName = art.name
                resolvedHostSubject = .art(art)
                resolvedHostDescription = art.description
                resolvedHostLocation = art.locationString ?? art.timeBasedAddress
                resolvedHostEvents = (try? await playaDB.fetchEvents(locatedAtArtUID: artUID)) ?? []
                needsRefresh = true
            }

        case .mutantVehicle(let mv):
            guard let playaDB else { break }
            try? await playaDB.setLastViewed(Date(), for: mv)
        }

        rowAssets?.startIfNeeded()

        if needsRefresh {
            self.cells = generateCells()
        }
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
            case .art(let art):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.toggleFavorite(art)
                isFavorite = try await playaDB.isFavorite(art)
                syncFavoriteToYapDB(uid: art.uid, yapCollection: BRCArtObject.yapCollection, isFavorite: isFavorite)
            case .camp(let camp):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.toggleFavorite(camp)
                isFavorite = try await playaDB.isFavorite(camp)
                syncFavoriteToYapDB(uid: camp.uid, yapCollection: BRCCampObject.yapCollection, isFavorite: isFavorite)
            case .event(let event):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.toggleFavorite(event)
                isFavorite = try await playaDB.isFavorite(event)
                syncFavoriteToYapDB(uid: event.uid, yapCollection: BRCEventObject.yapCollection, isFavorite: isFavorite, isEvent: true)
            case .eventOccurrence(let occ):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.toggleFavorite(occ)
                isFavorite = try await playaDB.isFavorite(occ)
                syncFavoriteToYapDB(uid: occ.event.uid, yapCollection: BRCEventObject.yapCollection, isFavorite: isFavorite, isEvent: true)
            case .mutantVehicle(let mv):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.toggleFavorite(mv)
                isFavorite = try await playaDB.isFavorite(mv)
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
            case .art(let art):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: art)
                userNotes = notes
                syncNotesToYapDB(uid: art.uid, yapCollection: BRCArtObject.yapCollection, notes: notes)
            case .camp(let camp):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: camp)
                userNotes = notes
                syncNotesToYapDB(uid: camp.uid, yapCollection: BRCCampObject.yapCollection, notes: notes)
            case .event(let event):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: event)
                userNotes = notes
                syncNotesToYapDB(uid: event.uid, yapCollection: BRCEventObject.yapCollection, notes: notes)
            case .eventOccurrence(let occ):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: occ.event)
                userNotes = notes
                syncNotesToYapDB(uid: occ.event.uid, yapCollection: BRCEventObject.yapCollection, notes: notes)
            case .mutantVehicle(let mv):
                guard let playaDB else { throw DetailError.invalidData }
                try await playaDB.setUserNotes(notes.isEmpty ? nil : notes, for: mv)
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

    // MARK: - YapDB Sync (backward compat during migration)

    private func syncFavoriteToYapDB(uid: String, yapCollection: String, isFavorite: Bool, isEvent: Bool = false) {
        Task.detached {
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                guard let object = transaction.object(forKey: uid, inCollection: yapCollection) as? BRCDataObject else { return }
                let metadata = object.metadata(with: transaction).metadataCopy()
                metadata.isFavorite = isFavorite
                object.replace(metadata, transaction: transaction)
                if isEvent, let event = object as? BRCEventObject {
                    event.refreshCalendarEntry(transaction)
                }
            }
        }
    }

    private func syncNotesToYapDB(uid: String, yapCollection: String, notes: String) {
        Task.detached {
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                guard let object = transaction.object(forKey: uid, inCollection: yapCollection) as? BRCDataObject else { return }
                let metadata = object.metadata(with: transaction).metadataCopy()
                metadata.userNotes = notes
                object.replace(metadata, transaction: transaction)
            }
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
            
        case .relationship(_, _, let onTap):
            onTap?()

        case .eventRelationship(_, _, let onTap):
            onTap?()

        case .nextHostEvent(_, _, _, let onTap):
            onTap?()

        case .allHostEvents(_, _, let onTap):
            onTap?()
            
        case .playaAddress(_, let tappable):
            if tappable {
                switch subject {
                case .legacy(let legacyObject):
                    coordinator.handle(.showMap(legacyObject))
                case .art(let art):
                    if let annotation = PlayaObjectAnnotation(art: art) {
                        coordinator.handle(.showMapAnnotation(annotation, title: "Map - \(art.name)"))
                    }
                case .camp(let camp):
                    if let annotation = PlayaObjectAnnotation(camp: camp) {
                        coordinator.handle(.showMapAnnotation(annotation, title: "Map - \(camp.name)"))
                    }
                case .event, .eventOccurrence, .mutantVehicle:
                    break
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
        case .art(let art):
            coordinator.handle(.share(["Art: \(art.name)\nID: \(art.uid)"]))
        case .camp(let camp):
            coordinator.handle(.share(["Camp: \(camp.name)\nID: \(camp.uid)"]))
        case .event(let event):
            coordinator.handle(.share(["Event: \(event.name)\nID: \(event.uid)"]))
        case .eventOccurrence(let occ):
            coordinator.handle(.share(["Event: \(occ.name)\nID: \(occ.event.uid)"]))
        case .mutantVehicle(let mv):
            coordinator.handle(.share(["Mutant Vehicle: \(mv.name)\nID: \(mv.uid)"]))
        }
    }
    
    /// Extract theme colors following the same logic as BRCDetailViewController
    func getThemeColors() -> ImageColors {
        ImageColors(getThemeBRCColors())
    }

    /// UIKit-friendly theme colors for navigation bar theming and legacy parity.
    func getThemeBRCColors() -> BRCImageColors {
        // If image colors theming is disabled, always return global theme colors
        if !Appearance.useImageColorsTheming {
            return Appearance.currentColors
        }

        switch subject {
        case .legacy(let legacyObject):
            // Special handling for events - try to get colors from hosting camp first
            if let eventObject = legacyObject as? BRCEventObject {
                return getEventThemeBRCColors(for: eventObject)
            }

            // For Art/Camp objects, check if metadata has thumbnail colors
            if let artMetadata = legacyMetadata as? BRCArtMetadata,
               let imageColors = artMetadata.thumbnailImageColors {
                return imageColors
            } else if let campMetadata = legacyMetadata as? BRCCampMetadata,
                      let imageColors = campMetadata.thumbnailImageColors {
                return imageColors
            }

            return Appearance.currentColors

        case .art, .camp, .event, .eventOccurrence, .mutantVehicle:
            if let colors = extractedImageColors {
                return colors
            }
            return Appearance.currentColors
        }
    }
    
    // MARK: - Audio State Management
    
    private func setupAudioNotificationObserver() {
	        audioNotificationObserver = NotificationCenter.default.addObserver(
	            forName: Notification.Name(BRCAudioPlayer.BRCAudioPlayerChangeNotification),
	            object: nil,
	            queue: .main
	        ) { [weak self] _ in
	            // The notification is delivered on the main queue; keep the update synchronous so
	            // UI/tests that expect immediate state changes behave deterministically.
	            MainActor.assumeIsolated {
	                self?.updateAudioPlayingState()
	            }
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

        case .art(let art):
            guard localAudioURL(objectID: art.uid) != nil else { return }
            isAudioPlaying = audioPlayer.isPlaying(id: art.uid)

        case .camp, .event, .eventOccurrence, .mutantVehicle:
            return
        }

        if wasPlaying != isAudioPlaying {
            cells = generateCells()
        }
    }
    
    /// Handle event-specific color logic - try hosting camp colors first
    private func getEventThemeBRCColors(for event: BRCEventObject) -> BRCImageColors {
        // Try to get colors from hosting camp's image first
        if let campId = event.hostedByCampUniqueID,
           let dataService,
           let camp = dataService.getCamp(withId: campId) {
            
            // Get camp metadata and check for image colors
            if let campMetadata = dataService.getMetadata(for: camp) as? BRCCampMetadata,
               let campImageColors = campMetadata.thumbnailImageColors {
                return campImageColors
            }
        }
        
        // Fallback to event type colors
        return BRCImageColors.colors(for: event.eventType)
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
            let md = legacyMetadata ?? BRCObjectMetadata()!
            return generateLegacyCellTypes(legacyObject, metadata: md, dataService: dataService)

        case .art(let art):
            return generatePlayaArtCellTypes(art)
        case .camp(let camp):
            return generatePlayaCampCellTypes(camp)
        case .event(let event):
            return generatePlayaEventCellTypes(event)
        case .eventOccurrence(let occ):
            return generatePlayaEventOccurrenceCellTypes(occ)
        case .mutantVehicle(let mv):
            return generatePlayaMutantVehicleCellTypes(mv)
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

    private func generatePlayaArtCellTypes(_ art: ArtObject) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        var hasImage = false

        if let imageURL = localThumbnailURL(objectID: art.uid),
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
            hasImage = true
        }

        let canShowLocation = BRCEmbargo.allowEmbargoedData()
        if canShowLocation, let annotation = PlayaObjectAnnotation(art: art), !hasImage {
            cellTypes.append(.mapAnnotation(annotation, title: "Map - \(art.name)"))
        }

        cellTypes.append(.text(art.name, style: .title))

        if let description = art.description, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }

        if let artist = art.artist, !artist.isEmpty {
            cellTypes.append(.text("Artist: \(artist)", style: .subtitle))
        }

        // Location with embargo handling
        let locationValue: String
        if canShowLocation, art.location != nil {
            locationValue = art.locationString ?? art.timeBasedAddress ?? "Unknown"
        } else if canShowLocation {
            locationValue = "Unknown"
        } else {
            locationValue = "Restricted"
        }
        cellTypes.append(.playaAddress(locationValue, tappable: canShowLocation && art.location != nil))

        // Media-driven audio tour (filesystem/bundle as source of truth)
        if let audioURL = localAudioURL(objectID: art.uid),
           let track = makeAudioTrack(objectID: art.uid, title: art.name, artist: art.artist, audioURL: audioURL) {
            cellTypes.append(.audioTrack(track, isPlaying: isAudioPlaying))
        }

        // Email / URL
        if let email = art.contactEmail, !email.isEmpty {
            cellTypes.append(.email(email, label: "Contact"))
        }
        if let url = art.url {
            cellTypes.append(.url(url, title: "Website"))
        }

        // Hosted events
        cellTypes.append(contentsOf: generateHostedEventCells(hostName: art.name))

        // Footer: map (if image), GPS, distance, travel time, notes
        cellTypes.append(contentsOf: generatePlayaFooterCells(
            annotation: PlayaObjectAnnotation(art: art),
            location: art.location,
            hasImage: hasImage,
            canShowLocation: canShowLocation,
            mapTitle: "Map - \(art.name)"
        ))
        return cellTypes
    }

    private func generatePlayaCampCellTypes(_ camp: CampObject) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        var hasImage = false

        if let imageURL = localThumbnailURL(objectID: camp.uid),
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
            hasImage = true
        }

        let canShowLocation = BRCEmbargo.allowEmbargoedData()
        if canShowLocation, let annotation = PlayaObjectAnnotation(camp: camp), !hasImage {
            cellTypes.append(.mapAnnotation(annotation, title: "Map - \(camp.name)"))
        }

        cellTypes.append(.text(camp.name, style: .title))

        if let description = camp.description, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }

        if let hometown = camp.hometown, !hometown.isEmpty {
            cellTypes.append(.text("Hometown: \(hometown)", style: .caption))
        }
        if let landmark = camp.landmark, !landmark.isEmpty {
            cellTypes.append(.landmark(landmark))
        }

        let locationValue: String
        if canShowLocation, camp.location != nil {
            locationValue = camp.locationString ?? camp.intersection ?? "Unknown"
        } else if canShowLocation {
            locationValue = "Unknown"
        } else {
            locationValue = "Restricted"
        }
        cellTypes.append(.playaAddress(locationValue, tappable: canShowLocation && camp.location != nil))

        // Email / URL
        if let email = camp.contactEmail, !email.isEmpty {
            cellTypes.append(.email(email, label: "Contact"))
        }
        if let url = camp.url {
            cellTypes.append(.url(url, title: "Website"))
        }

        // Hosted events
        cellTypes.append(contentsOf: generateHostedEventCells(hostName: camp.name))

        // Footer: map (if image), GPS, distance, travel time, notes
        cellTypes.append(contentsOf: generatePlayaFooterCells(
            annotation: PlayaObjectAnnotation(camp: camp),
            location: camp.location,
            hasImage: hasImage,
            canShowLocation: canShowLocation,
            mapTitle: "Map - \(camp.name)"
        ))
        return cellTypes
    }

    private func generatePlayaMutantVehicleCellTypes(_ mv: MutantVehicleObject) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []

        if let imageURL = localThumbnailURL(objectID: mv.uid),
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
        }

        cellTypes.append(.text(mv.name, style: .title))

        if let description = mv.description, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }

        if let artist = mv.artist, !artist.isEmpty {
            cellTypes.append(.text("Artist: \(artist)", style: .subtitle))
        }

        if let hometown = mv.hometown, !hometown.isEmpty {
            cellTypes.append(.text("Hometown: \(hometown)", style: .caption))
        }

        if let email = mv.contactEmail, !email.isEmpty {
            cellTypes.append(.email(email, label: "Contact"))
        }
        if let url = mv.url {
            cellTypes.append(.url(url, title: "Website"))
        }
        if let donationLink = mv.donationLink {
            cellTypes.append(.url(donationLink, title: "Donate"))
        }

        cellTypes.append(.userNotes(userNotes))

        return cellTypes
    }

    private func generatePlayaEventCellTypes(_ event: EventObject) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []

        cellTypes.append(.text(event.name, style: .title))

        if let description = event.description, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }

        let canShowLocation = BRCEmbargo.allowEmbargoedData()
        let locationValue: String
        if canShowLocation, let hostName = resolvedHostName {
            locationValue = hostName
        } else if canShowLocation, !event.otherLocation.isEmpty {
            locationValue = event.otherLocation
        } else if canShowLocation {
            locationValue = "Unknown"
        } else {
            locationValue = "Restricted"
        }
        cellTypes.append(.playaAddress(locationValue, tappable: false))

        if let url = event.url {
            cellTypes.append(.url(url, title: "Website"))
        }

        cellTypes.append(.userNotes(userNotes))
        return cellTypes
    }

    private func generatePlayaEventOccurrenceCellTypes(_ occ: EventObjectOccurrence) -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        guard let playaDB else { return cellTypes }

        var hasImage = false

        // Host image (camp or art thumbnail)
        let hostUID = occ.hostedByCamp ?? occ.locatedAtArt
        if let hostUID,
           let imageURL = localThumbnailURL(objectID: hostUID),
           let image = loadImage(from: imageURL) {
            let aspectRatio = image.size.width / image.size.height
            cellTypes.append(.image(image, aspectRatio: aspectRatio))
            hasImage = true
        }

        // Map before title if no host image
        let canShowLocation = BRCEmbargo.allowEmbargoedData()
        let annotation = eventAnnotation(for: occ)
        if canShowLocation, let annotation, !hasImage {
            cellTypes.append(.mapAnnotation(annotation, title: "Map - \(occ.name)"))
        }

        // Title
        cellTypes.append(.text(occ.name, style: .title))

        // Description
        if let description = occ.description, !description.isEmpty {
            cellTypes.append(.text(description, style: .body))
        }

        // Host relationship
        if let hostName = resolvedHostName, let hostSubject = resolvedHostSubject {
            let relationshipType: RelationshipType = occ.isHostedByCamp
                ? .hostedBy(hostName)
                : .presentedBy(hostName)
            cellTypes.append(.relationship(
                title: hostName,
                type: relationshipType,
                onTap: { [weak self] in
                    guard let self else { return }
                    let vc = DetailViewControllerFactory.create(with: hostSubject, playaDB: playaDB)
                    self.coordinator.handle(.navigateToViewController(vc))
                }
            ))
        }

        // Next event by same host
        let otherEvents = resolvedHostEvents.filter { $0.event.uid != occ.event.uid }
        let now = Date()
        if let nextEvent = otherEvents.first(where: { $0.startDate > now }) {
            let scheduleText = Self.formatEventTimeAndDuration(
                startDate: nextEvent.startDate,
                endDate: nextEvent.endDate
            )
            cellTypes.append(.nextHostEvent(
                title: nextEvent.name,
                scheduleText: scheduleText,
                hostName: resolvedHostName ?? "",
                onTap: { [weak self] in
                    guard let self else { return }
                    let vc = DetailViewControllerFactory.create(with: nextEvent, playaDB: playaDB)
                    self.coordinator.handle(.navigateToViewController(vc))
                }
            ))
        }

        // All events by host
        if otherEvents.count > 0, let hostName = resolvedHostName {
            cellTypes.append(.allHostEvents(
                count: otherEvents.count,
                hostName: hostName,
                onTap: { [weak self] in
                    guard let self else { return }
                    let vc = PlayaHostedEventsViewController(
                        events: self.resolvedHostEvents,
                        hostName: hostName,
                        playaDB: playaDB
                    )
                    self.coordinator.handle(.navigateToViewController(vc))
                }
            ))
        }

        // Schedule with color-coded time
        let scheduleString = formatPlayaEventSchedule(occ: occ)
        cellTypes.append(.schedule(scheduleString))

        // Location
        let locationValue: String
        if canShowLocation, let hostLoc = resolvedHostLocation, !hostLoc.isEmpty {
            locationValue = hostLoc
        } else if canShowLocation, !occ.otherLocation.isEmpty {
            locationValue = occ.otherLocation
        } else if canShowLocation {
            locationValue = "Unknown"
        } else {
            locationValue = "Restricted"
        }
        cellTypes.append(.playaAddress(locationValue, tappable: false))

        // Event type
        cellTypes.append(.eventType(
            emoji: EventTypeInfo.emoji(for: occ.eventTypeCode),
            label: EventTypeInfo.displayName(for: occ.eventTypeCode)
        ))

        // Host description
        if let hostDesc = resolvedHostDescription, !hostDesc.isEmpty {
            cellTypes.append(.text(hostDesc, style: .body))
        }

        // Contact / URL
        if let contact = occ.contact, !contact.isEmpty {
            if contact.contains("@") {
                cellTypes.append(.email(contact, label: "Contact"))
            }
        }
        if let url = occ.url {
            cellTypes.append(.url(url, title: "Website"))
        }

        // Footer: map (if image), GPS, distance, travel time, notes
        let location = effectiveLocation(for: occ)
        cellTypes.append(contentsOf: generatePlayaFooterCells(
            annotation: annotation,
            location: location,
            hasImage: hasImage,
            canShowLocation: canShowLocation,
            mapTitle: "Map - \(occ.name)"
        ))

        return cellTypes
    }

    /// Build schedule attributed string for a PlayaDB event occurrence.
    private func formatPlayaEventSchedule(occ: EventObjectOccurrence) -> NSAttributedString {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE M/d"
        dayFormatter.timeZone = TimeZone.burningManTimeZone

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = TimeZone.burningManTimeZone

        let dayString = dayFormatter.string(from: occ.startDate)
        let timeString: String
        if occ.allDay {
            let start = timeFormatter.string(from: occ.startDate)
            let end = timeFormatter.string(from: occ.endDate)
            timeString = "All Day (\(start) - \(end))"
        } else {
            let start = timeFormatter.string(from: occ.startDate)
            let end = timeFormatter.string(from: occ.endDate)
            timeString = "\(start) - \(end)"
        }

        let fullString = "\(dayString)\n\(timeString)"
        let attributedString = NSMutableAttributedString(string: fullString)

        let now = Date()
        let timeColor: UIColor
        if now < occ.startDate {
            timeColor = .systemGreen
        } else if now >= occ.startDate && now <= occ.endDate {
            timeColor = .systemOrange
        } else {
            timeColor = .systemRed
        }
        let timeRange = NSRange(location: dayString.count + 1, length: timeString.count)
        attributedString.addAttribute(.foregroundColor, value: timeColor, range: timeRange)

        return attributedString
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
            let scheduleText = Self.formatEventTimeAndDuration(
                startDate: nextEvent.startDate as Date?,
                endDate: nextEvent.endDate as Date?
            )
            cells.append(.nextHostEvent(
                title: nextEvent.title,
                scheduleText: scheduleText,
                hostName: art.title,
                onTap: { [weak self] in self?.coordinator.handle(.navigateToObject(nextEvent)) }
            ))
        }

        // Hosted events
        if let events = dataService.getEvents(for: art), !events.isEmpty {
            cells.append(.eventRelationship(
                count: events.count,
                hostName: art.title,
                onTap: { [weak self] in self?.coordinator.handle(.showEventsList(events, hostName: art.title)) }
            ))
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
            let scheduleText = Self.formatEventTimeAndDuration(
                startDate: nextEvent.startDate as Date?,
                endDate: nextEvent.endDate as Date?
            )
            cells.append(.nextHostEvent(
                title: nextEvent.title,
                scheduleText: scheduleText,
                hostName: camp.title,
                onTap: { [weak self] in self?.coordinator.handle(.navigateToObject(nextEvent)) }
            ))
        }

        // Hosted events
        if let events = dataService.getEvents(for: camp), !events.isEmpty {
            cells.append(.eventRelationship(
                count: events.count,
                hostName: camp.title,
                onTap: { [weak self] in self?.coordinator.handle(.showEventsList(events, hostName: camp.title)) }
            ))
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
            cells.append(.relationship(
                title: camp.title,
                type: .hostedBy(camp.title),
                onTap: { [weak self] in self?.coordinator.handle(.navigateToObject(camp)) }
            ))
            hostName = camp.title
            hostId = campId
        } else if let artId = event.hostedByArtUniqueID,
                  let art = dataService.getArt(withId: artId) {
            cells.append(.relationship(
                title: art.title,
                type: .hostedBy(art.title),
                onTap: { [weak self] in self?.coordinator.handle(.navigateToObject(art)) }
            ))
            hostName = art.title
            hostId = artId
        }
        
        // Next event and all events from the same host
        if let hostId = hostId, let hostName = hostName {
            // Get next event from the same host
            if let nextEvent = dataService.getNextEvent(forHostId: hostId, after: event) {
                let scheduleText = Self.formatEventTimeAndDuration(
                    startDate: nextEvent.startDate as Date?,
                    endDate: nextEvent.endDate as Date?
                )
                cells.append(.nextHostEvent(
                    title: nextEvent.title,
                    scheduleText: scheduleText,
                    hostName: hostName,
                    onTap: { [weak self] in self?.coordinator.handle(.navigateToObject(nextEvent)) }
                ))
            }

            // Get count of other events and show "see all" if more than just next event
            let otherEventsCount = dataService.getOtherEventsCount(forHostId: hostId, excluding: event)
            if otherEventsCount > 0 {
                cells.append(.allHostEvents(
                    count: otherEventsCount,
                    hostName: hostName,
                    onTap: { [weak self] in
                        guard let self else { return }
                        var allEvents: [BRCEventObject] = []
                        if let camp = dataService.getCamp(withId: hostId) {
                            allEvents = dataService.getEvents(for: camp) ?? []
                        } else if let art = dataService.getArt(withId: hostId) {
                            allEvents = dataService.getEvents(for: art) ?? []
                        }
                        self.coordinator.handle(.showEventsList(allEvents, hostName: hostName))
                    }
                ))
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
        cells.append(.eventType(emoji: event.eventType.emoji, label: event.eventType.displayString))

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

    /// Formats start/end dates into a "Day at Time - Duration" string.
    /// Shared between legacy and PlayaDB paths.
    static func formatEventTimeAndDuration(startDate: Date?, endDate: Date?) -> String {
        guard let startDate, let endDate else { return "" }
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = TimeZone.burningManTimeZone

        var timeString: String
        if calendar.isDateInToday(startDate) {
            timeString = "Today at \(timeFormatter.string(from: startDate))"
        } else if calendar.isDateInTomorrow(startDate) {
            timeString = "Tomorrow at \(timeFormatter.string(from: startDate))"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE M/d"
            dayFormatter.timeZone = TimeZone.burningManTimeZone
            timeString = "\(dayFormatter.string(from: startDate)) at \(timeFormatter.string(from: startDate))"
        }

        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        let durationString: String
        if hours > 0 && minutes > 0 {
            durationString = "\(hours)h \(minutes)m"
        } else if hours > 0 {
            durationString = "\(hours)h"
        } else {
            durationString = "\(minutes)m"
        }

        return "\(timeString) \u{2022} \(durationString)"
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
        guard let dataService else { return nil }
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
        // Check preloaded cache first
        if let cached = preloadedImages[url.path] {
            return cached
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Preload images off the main thread before cell generation
    private func preloadImages() async {
        var urls: [URL] = []

        switch subject {
        case .legacy(let obj):
            if let artObj = obj as? BRCArtObject, let url = artObj.localThumbnailURL {
                urls.append(url)
            } else if let campObj = obj as? BRCCampObject, let url = campObj.localThumbnailURL {
                urls.append(url)
            } else if let eventObj = obj as? BRCEventObject {
                if let campId = eventObj.hostedByCampUniqueID,
                   let camp = dataService?.getCamp(withId: campId),
                   let url = camp.localThumbnailURL {
                    urls.append(url)
                }
                if let artId = eventObj.hostedByArtUniqueID,
                   let art = dataService?.getArt(withId: artId),
                   let url = art.localThumbnailURL {
                    urls.append(url)
                }
            }
        case .art(let art):
            if let url = localThumbnailURL(objectID: art.uid) { urls.append(url) }
        case .camp(let camp):
            if let url = localThumbnailURL(objectID: camp.uid) { urls.append(url) }
        case .event(let event):
            if let hostUID = event.hostedByCamp ?? event.locatedAtArt,
               let url = localThumbnailURL(objectID: hostUID) { urls.append(url) }
        case .eventOccurrence(let occ):
            if let hostUID = occ.hostedByCamp ?? occ.locatedAtArt,
               let url = localThumbnailURL(objectID: hostUID) { urls.append(url) }
        case .mutantVehicle(let mv):
            if let url = localThumbnailURL(objectID: mv.uid) { urls.append(url) }
        }

        let loaded = await Task.detached(priority: .userInitiated) {
            var result: [String: UIImage] = [:]
            for url in urls {
                if FileManager.default.fileExists(atPath: url.path),
                   let image = UIImage(contentsOfFile: url.path) {
                    result[url.path] = image
                }
            }
            return result
        }.value

        preloadedImages = loaded
    }

    private func loadHostCampImage(for event: BRCEventObject, dataService: DetailDataServiceProtocol) -> UIImage? {
        guard let campId = event.hostedByCampUniqueID else { return nil }

        if let camp = dataService.getCamp(withId: campId),
           let imageURL = camp.localThumbnailURL {
            return loadImage(from: imageURL)
        }

        return nil
    }

    private func loadHostArtImage(for event: BRCEventObject, dataService: DetailDataServiceProtocol) -> UIImage? {
        guard let artId = event.hostedByArtUniqueID else { return nil }

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

    /// Best available CLLocation for an event occurrence — prefers event's own GPS, falls back to host.
    private func effectiveLocation(for occ: EventObjectOccurrence) -> CLLocation? {
        if let loc = occ.location { return loc }
        switch resolvedHostSubject {
        case .camp(let camp): return camp.location
        case .art(let art): return art.location
        default: return nil
        }
    }

    /// Map annotation for an event — tries event's own GPS, falls back to host camp/art.
    private func eventAnnotation(for occ: EventObjectOccurrence) -> PlayaObjectAnnotation? {
        if let annotation = PlayaObjectAnnotation(event: occ) { return annotation }
        switch resolvedHostSubject {
        case .camp(let camp): return PlayaObjectAnnotation(camp: camp)
        case .art(let art): return PlayaObjectAnnotation(art: art)
        default: return nil
        }
    }

    /// Shared footer cells: map (if header image exists), GPS, distance, travel time, user notes.
    private func generatePlayaFooterCells(
        annotation: PlayaObjectAnnotation?,
        location: CLLocation?,
        hasImage: Bool,
        canShowLocation: Bool,
        mapTitle: String
    ) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        if canShowLocation, let annotation, hasImage {
            cells.append(.mapAnnotation(annotation, title: mapTitle))
        }
        if canShowLocation, let location {
            cells.append(.coordinates(location.coordinate, label: "GPS Coordinates"))
        }
        if canShowLocation, let distance = distanceToLocation(location) {
            cells.append(.distance(distance))
            cells.append(.travelTime(distance))
        }
        cells.append(.userNotes(userNotes))
        return cells
    }

    /// Generate hosted event cells (next event + all events) for a camp/art detail screen.
    private func generateHostedEventCells(hostName: String) -> [DetailCellType] {
        guard let playaDB, !resolvedHostEvents.isEmpty else { return [] }
        var cells: [DetailCellType] = []
        let now = Date()

        // Next upcoming event
        if let nextEvent = resolvedHostEvents.first(where: { $0.startDate > now }) {
            let scheduleText = Self.formatEventTimeAndDuration(
                startDate: nextEvent.startDate,
                endDate: nextEvent.endDate
            )
            cells.append(.nextHostEvent(
                title: nextEvent.name,
                scheduleText: scheduleText,
                hostName: hostName,
                onTap: { [weak self] in
                    guard let self else { return }
                    let vc = DetailViewControllerFactory.create(with: nextEvent, playaDB: playaDB)
                    self.coordinator.handle(.navigateToViewController(vc))
                }
            ))
        }

        // All events button
        cells.append(.allHostEvents(
            count: resolvedHostEvents.count,
            hostName: hostName,
            onTap: { [weak self] in
                guard let self else { return }
                let vc = PlayaHostedEventsViewController(
                    events: self.resolvedHostEvents,
                    hostName: hostName,
                    playaDB: playaDB
                )
                self.coordinator.handle(.navigateToViewController(vc))
            }
        ))

        return cells
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
