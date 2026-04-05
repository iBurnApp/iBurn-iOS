//
//  AIAssistantViewModel.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

@MainActor
final class AIAssistantViewModel: ObservableObject {

    enum Feature: String, CaseIterable, Identifiable {
        case forYou = "For You"
        case dayPlan = "Day Plan"
        case nearby = "Nearby"
        var id: String { rawValue }
    }

    // MARK: - Published State

    @Published var selectedFeature: Feature = .forYou
    @Published var recommendations: [AIRecommendation] = []
    @Published var dayPlan: AIDayPlan?
    @Published var nearbyHighlights: [AINearbyHighlight] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Resolved objects for display (uid -> actual PlayaDB model)
    @Published var resolvedObjects: [String: ResolvedObject] = [:]
    @Published var favoriteIDs: Set<String> = []

    enum ResolvedObject {
        case art(ArtObject)
        case camp(CampObject)
        case event(EventObject)
        case mutantVehicle(MutantVehicleObject)

        var objectType: DataObjectType {
            switch self {
            case .art: return .art
            case .camp: return .camp
            case .event: return .event
            case .mutantVehicle: return .mutantVehicle
            }
        }
    }

    // MARK: - Dependencies

    private let aiService: AIAssistantService
    let playaDB: PlayaDB
    private let locationProvider: LocationProvider

    private var loadTask: Task<Void, Never>?

    init(aiService: AIAssistantService, playaDB: PlayaDB, locationProvider: LocationProvider) {
        self.aiService = aiService
        self.playaDB = playaDB
        self.locationProvider = locationProvider
    }

    // MARK: - Actions

    func loadCurrentFeature() {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                switch self.selectedFeature {
                case .forYou:
                    let results = try await self.aiService.recommend()
                    guard !Task.isCancelled else { return }
                    await self.resolveUIDs(results.map(\.uid))
                    self.recommendations = results

                case .dayPlan:
                    let plan = try await self.aiService.planDay(
                        date: Date(),
                        location: self.locationProvider.currentLocation
                    )
                    guard !Task.isCancelled else { return }
                    await self.resolveUIDs(plan.schedule.map(\.uid))
                    self.dayPlan = plan

                case .nearby:
                    guard let location = self.locationProvider.currentLocation else {
                        self.errorMessage = "Location not available. Enable location services to use this feature."
                        self.isLoading = false
                        return
                    }
                    let highlights = try await self.aiService.whatsNearby(location: location)
                    guard !Task.isCancelled else { return }
                    await self.resolveUIDs(highlights.map(\.uid))
                    self.nearbyHighlights = highlights
                }
                self.isLoading = false
            } catch is CancellationError {
                // Ignored
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = "AI is thinking too hard. Try again."
                self.isLoading = false
                print("AI Assistant error: \(error)")
            }
        }
    }

    /// Fetch actual objects from PlayaDB for display and navigation
    private func resolveUIDs(_ uids: [String]) async {
        for uid in uids where resolvedObjects[uid] == nil {
            if let art = try? await playaDB.fetchArt(uid: uid) {
                resolvedObjects[uid] = .art(art)
                if let isFav = try? await playaDB.isFavorite(art), isFav {
                    favoriteIDs.insert(uid)
                }
            } else if let camp = try? await playaDB.fetchCamp(uid: uid) {
                resolvedObjects[uid] = .camp(camp)
                if let isFav = try? await playaDB.isFavorite(camp), isFav {
                    favoriteIDs.insert(uid)
                }
            } else if let event = try? await playaDB.fetchEvent(uid: uid) {
                resolvedObjects[uid] = .event(event)
                if let isFav = try? await playaDB.isFavorite(event), isFav {
                    favoriteIDs.insert(uid)
                }
            } else if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                resolvedObjects[uid] = .mutantVehicle(mv)
                if let isFav = try? await playaDB.isFavorite(mv), isFav {
                    favoriteIDs.insert(uid)
                }
            }
        }
    }

    func toggleFavorite(_ uid: String) async {
        guard let resolved = resolvedObjects[uid] else { return }
        do {
            switch resolved {
            case .art(let art):
                try await playaDB.toggleFavorite(art)
                let isFav = try await playaDB.isFavorite(art)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .camp(let camp):
                try await playaDB.toggleFavorite(camp)
                let isFav = try await playaDB.isFavorite(camp)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .event(let event):
                try await playaDB.toggleFavorite(event)
                let isFav = try await playaDB.isFavorite(event)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .mutantVehicle(let mv):
                try await playaDB.toggleFavorite(mv)
                let isFav = try await playaDB.isFavorite(mv)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            }
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }
}
