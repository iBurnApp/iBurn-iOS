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

@MainActor
class DetailViewModel: ObservableObject {
    // MARK: - Published State
    @Published var dataObject: BRCDataObject
    @Published var metadata: BRCObjectMetadata
    @Published var cells: [DetailCell] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAudioPlaying = false
    
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
            
        case .playaAddress(_, let tappable):
            if tappable {
                coordinator.handle(.showMap(dataObject))
            }
            
        case .image(let image, _):
            coordinator.handle(.showImageViewer(image))
            
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
    
    // MARK: - Private Methods
    
    private func generateCells() -> [DetailCell] {
        let cellTypes = generateCellTypes()
        return cellTypes.map { DetailCell($0) }
    }
    
    private func generateCellTypes() -> [DetailCellType] {
        var cellTypes: [DetailCellType] = []
        
        // Add title as first text cell
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
        
        return cellTypes
    }
    
    private func generateArtCells(_ art: BRCArtObject) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Artist name
        let artistName = art.artistName
        if !artistName.isEmpty {
            cells.append(.text("Artist: \(artistName)", style: .subtitle))
        }
        
        // Audio tour
        if art.audioURL != nil {
            let isPlaying = audioService.isPlaying(artObject: art)
            cells.append(.audio(art, isPlaying: isPlaying))
        }
        
        return cells
    }
    
    private func generateCampCells(_ camp: BRCCampObject) -> [DetailCellType] {
        let cells: [DetailCellType] = []
        
        // Add camp-specific information here
        // For now, just common cells will be added
        
        return cells
    }
    
    private func generateEventCells(_ event: BRCEventObject) -> [DetailCellType] {
        var cells: [DetailCellType] = []
        
        // Schedule information
        // Note: Despite being declared as non-nullable in Obj-C, these can be nil internally
        // This is a bridging issue - in production these dates are always valid
        if let startDate = event.startDate as Date?,
           let endDate = event.endDate as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            var scheduleText = "Starts: \(formatter.string(from: startDate))"
            scheduleText += "\nEnds: \(formatter.string(from: endDate))"
            
            cells.append(.text(scheduleText, style: .caption))
        }
        
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
        
        // Playa location
        if let playaLocation = dataObject.playaLocation, !playaLocation.isEmpty {
            cells.append(.playaAddress(playaLocation, tappable: true))
        }
        
        // GPS coordinates
        if let location = dataObject.location {
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
}