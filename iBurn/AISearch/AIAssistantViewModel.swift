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

    /// Resolved objects for display (uid -> name, type, etc.)
    @Published var resolvedObjects: [String: ResolvedItem] = [:]

    struct ResolvedItem: Identifiable {
        let uid: String
        let name: String
        let objectType: DataObjectType
        let subtitle: String?
        var id: String { uid }
    }

    // MARK: - Dependencies

    private let aiService: AIAssistantService
    private let playaDB: PlayaDB
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

    /// Fetch actual objects from PlayaDB to get display names
    private func resolveUIDs(_ uids: [String]) async {
        for uid in uids where resolvedObjects[uid] == nil {
            if let art = try? await playaDB.fetchArt(uid: uid) {
                resolvedObjects[uid] = ResolvedItem(
                    uid: uid, name: art.name, objectType: .art,
                    subtitle: art.artist
                )
            } else if let camp = try? await playaDB.fetchCamp(uid: uid) {
                resolvedObjects[uid] = ResolvedItem(
                    uid: uid, name: camp.name, objectType: .camp,
                    subtitle: camp.hometown
                )
            } else if let event = try? await playaDB.fetchEvent(uid: uid) {
                resolvedObjects[uid] = ResolvedItem(
                    uid: uid, name: event.name, objectType: .event,
                    subtitle: event.eventTypeLabel
                )
            } else if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                resolvedObjects[uid] = ResolvedItem(
                    uid: uid, name: mv.name, objectType: .mutantVehicle,
                    subtitle: mv.artist
                )
            }
        }
    }
}
