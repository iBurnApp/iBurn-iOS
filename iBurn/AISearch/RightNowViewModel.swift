//
//  RightNowViewModel.swift
//  iBurn
//
//  View model for the single AI Guide screen: "what's near you happening now,
//  and what to do next."
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
import MapKit
import FoundationModels
@preconcurrency import PlayaDB

@available(iOS 26, *)
@MainActor
final class RightNowViewModel: ObservableObject {

    /// Where to look: the user's current location, or a map-selected area.
    enum PlaceScope: Equatable {
        case nearMe
        case area(MKCoordinateRegion)

        static func == (lhs: PlaceScope, rhs: PlaceScope) -> Bool {
            switch (lhs, rhs) {
            case (.nearMe, .nearMe): return true
            case let (.area(a), .area(b)):
                return a.center.latitude == b.center.latitude
                    && a.center.longitude == b.center.longitude
                    && a.span.latitudeDelta == b.span.latitudeDelta
                    && a.span.longitudeDelta == b.span.longitudeDelta
            default: return false
            }
        }
    }

    // MARK: - Inputs
    @Published var queryText: String = ""
    @Published var selectedChipID: String?
    @Published var timeOfDay: TimeOfDay = .now
    @Published var selectedDay: Date = RightNowViewModel.defaultFestivalDay()
    @Published var place: PlaceScope = .nearMe

    /// The festival day matching today (in BRC time) if the event is running, otherwise the
    /// first festival day. Used as the default for the day-of-week selector.
    static func defaultFestivalDay() -> Date {
        let now = Date.present
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .burningManTimeZone
        if let today = YearSettings.festivalDays.first(where: { calendar.isDate($0, inSameDayAs: now) }) {
            return today
        }
        return YearSettings.festivalDays.first ?? now
    }

    // MARK: - Output
    @Published var executionState: WorkflowExecutionState = .idle
    @Published var steps: [WorkflowStepProgress] = []
    @Published var result: RightNowResult?
    @Published var resolvedObjects: [String: AIResolvedObject] = [:]
    @Published var favoriteIDs: Set<String> = []

    // MARK: - Dependencies
    let playaDB: PlayaDB
    let orchestrator: AgentOrchestrator
    private var currentTask: Task<Void, Never>?
    private static let maxRetries = 2

    init(playaDB: PlayaDB, orchestrator: AgentOrchestrator) {
        self.playaDB = playaDB
        self.orchestrator = orchestrator
    }

    var isRunning: Bool {
        if case .running = executionState { return true }
        return false
    }

    var hasResult: Bool { result != nil }

    // MARK: - Actions

    /// Tap a suggestion chip: seed the vibe/lean and run immediately.
    func selectChip(_ chip: SuggestionChip) {
        selectedChipID = chip.id
        queryText = chip.vibe
        run(vibe: chip.vibe, lean: chip.lean)
    }

    /// Run from the free-text field.
    func go() {
        selectedChipID = nil
        run(vibe: queryText.trimmingCharacters(in: .whitespacesAndNewlines), lean: .balanced)
    }

    func clearArea() { place = .nearMe }

    private func run(vibe: String, lean: DiscoveryLean) {
        currentTask?.cancel()
        steps = []
        result = nil
        executionState = .running

        let region: MKCoordinateRegion?
        switch place {
        case .nearMe: region = nil
        case .area(let r): region = r
        }
        let window = timeOfDay.dateWindow(on: selectedDay)

        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.execute(vibe: vibe, lean: lean, region: region, window: window, attempt: 0)
        }
    }

    private func execute(
        vibe: String,
        lean: DiscoveryLean,
        region: MKCoordinateRegion?,
        window: (start: Date, end: Date),
        attempt: Int
    ) async {
        do {
            let res = try await orchestrator.execute(
                RightNowWorkflow(),
                region: region,
                window: window,
                vibe: vibe,
                lean: lean
            ) { [weak self] progress in
                self?.handleProgress(progress)
            }
            guard !Task.isCancelled else { return }
            await resolveUIDs(res.now.map(\.uid) + res.next.map(\.uid))
            result = res
            executionState = .completed
        } catch is CancellationError {
            // Ignored
        } catch {
            guard !Task.isCancelled else { return }
            if attempt < Self.maxRetries, isRetryable(error) {
                markCurrentStepFailed()
                steps.removeAll()
                addStep(retryMessage(for: error))
                await execute(vibe: vibe, lean: lean, region: region, window: window, attempt: attempt + 1)
            } else {
                markCurrentStepFailed()
                #if DEBUG
                executionState = .failed("\(userFacingMessage(for: error))\n\n[DEBUG: \(error)]")
                #else
                executionState = .failed(userFacingMessage(for: error))
                #endif
            }
        }
    }

    // MARK: - Error Copy (concise, honest, no snark)

    private func isRetryable(_ error: Error) -> Bool {
        isGuardrailError(error) || isContextWindowError(error)
    }

    private func retryMessage(for error: Error) -> String {
        isContextWindowError(error) ? "Narrowing the search…" : "Trying again…"
    }

    private func userFacingMessage(for error: Error) -> String {
        if isGuardrailError(error) {
            return "Couldn't process that — try a different vibe."
        } else if isContextWindowError(error) {
            return "Too much to sift through — narrow the area or time."
        } else if case LanguageModelSession.GenerationError.unsupportedLanguageOrLocale = error {
            return "AI features need English language settings on this device."
        } else if case LanguageModelSession.GenerationError.rateLimited = error {
            return "The AI is busy. Try again in a moment."
        } else if case LanguageModelSession.GenerationError.assetsUnavailable = error {
            return "AI model unavailable — enable Apple Intelligence in Settings."
        } else {
            return "Something went wrong. Try again."
        }
    }

    // MARK: - Progress

    private func handleProgress(_ progress: WorkflowProgress) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch progress {
            case .stepStarted(_, let description): self.addStep(description)
            case .stepCompleted: self.completeCurrentStep()
            case .intermediateResult: break
            }
        }
    }

    private func addStep(_ message: String) {
        steps.append(WorkflowStepProgress(message: message, state: .running))
    }

    private func completeCurrentStep() {
        guard let idx = steps.lastIndex(where: { $0.state == .running }) else { return }
        steps[idx].state = .completed
    }

    private func markCurrentStepFailed() {
        guard let idx = steps.lastIndex(where: { $0.state == .running }) else { return }
        steps[idx].state = .failed
    }

    // MARK: - Object Resolution

    func resolveUIDs(_ uids: [String]) async {
        let unresolved = uids.filter { resolvedObjects[$0] == nil }
        guard !unresolved.isEmpty else { return }
        guard let objects = try? await playaDB.fetchObjects(byUIDs: unresolved) else { return }
        for obj in objects {
            if let art = obj as? ArtObject {
                resolvedObjects[art.uid] = .art(art)
            } else if let camp = obj as? CampObject {
                resolvedObjects[camp.uid] = .camp(camp)
            } else if let event = obj as? EventObject {
                resolvedObjects[event.uid] = .event(event)
            } else if let mv = obj as? MutantVehicleObject {
                resolvedObjects[mv.uid] = .mutantVehicle(mv)
            }
        }
        let favorites = (try? await playaDB.getFavorites()) ?? []
        let favUIDs = Set(favorites.map(\.uid))
        for uid in unresolved where favUIDs.contains(uid) {
            favoriteIDs.insert(uid)
        }
    }

    func toggleFavorite(_ uid: String) async {
        guard let resolved = resolvedObjects[uid] else { return }
        do {
            switch resolved {
            case .art(let art):
                try await playaDB.toggleFavorite(art)
                if try await playaDB.isFavorite(art) { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .camp(let camp):
                try await playaDB.toggleFavorite(camp)
                if try await playaDB.isFavorite(camp) { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .event(let event):
                try await playaDB.toggleFavorite(event)
                if try await playaDB.isFavorite(event) { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .mutantVehicle(let mv):
                try await playaDB.toggleFavorite(mv)
                if try await playaDB.isFavorite(mv) { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            }
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }
}

#endif
