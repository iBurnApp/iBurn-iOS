//
//  ObjectListViewModel.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import CoreLocation
import Dispatch
import Foundation
import PlayaDB

@MainActor
final class ObjectListViewModel<Object: DisplayableObject, Filter: Codable & FavoritesFilterable>: ObservableObject {
    // MARK: - Published

    @Published var items: [ListRow<Object>] = []

    @Published var filter: Filter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }

    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?

    // MARK: - Dependencies

    private let dataProvider: any ObjectListDataProvider<Object, Filter>
    private let locationProvider: LocationProvider
    private let filterStorageKey: String
    private let effectiveFilterForObservation: (Filter) -> Filter
    private let matchesSearch: (Object, String) -> Bool
    private let isDatabaseSeeded: (() async -> Bool)?

    // MARK: - Tasks

    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var loadingGateTask: Task<Void, Never>?

    // MARK: - Init

    init<DataProvider: ObjectListDataProvider>(
        dataProvider: DataProvider,
        locationProvider: LocationProvider,
        filterStorageKey: String,
        initialFilter: Filter,
        effectiveFilterForObservation: @escaping (Filter) -> Filter,
        favoritesFilterForObservation: @escaping (Filter) -> Filter = { $0 },
        matchesSearch: @escaping (Object, String) -> Bool,
        isDatabaseSeeded: (() async -> Bool)? = nil
    ) where DataProvider.Object == Object, DataProvider.Filter == Filter {
        self.dataProvider = dataProvider
        self.locationProvider = locationProvider
        self.filterStorageKey = filterStorageKey
        self.effectiveFilterForObservation = effectiveFilterForObservation
        self.matchesSearch = matchesSearch
        self.isDatabaseSeeded = isDatabaseSeeded

        self.filter = Self.loadFilter(key: filterStorageKey) ?? initialFilter
        self.currentLocation = locationProvider.currentLocation

        startObserving()
        startLocationUpdates()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
        loadingGateTask?.cancel()
    }

    // MARK: - Derived

    func isFavorite(_ object: Object) -> Bool {
        items.first(where: { $0.object.uid == object.uid })?.isFavorite ?? false
    }

    func distanceAttributedString(for object: Object) -> AttributedString? {
        dataProvider.distanceAttributedString(from: currentLocation, to: object)
    }

    var filteredItems: [ListRow<Object>] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter { matchesSearch($0.object, q) }
    }

    // MARK: - Actions

    func toggleFavorite(_ row: ListRow<Object>) async {
        let originalRow = row
        // Optimistic update
        if let idx = items.firstIndex(where: { $0.object.uid == row.object.uid }) {
            var updatedMeta = row.metadata
            updatedMeta?.isFavorite = !row.isFavorite
            items[idx] = ListRow(object: row.object, metadata: updatedMeta, thumbnailColors: row.thumbnailColors)
        }
        do {
            try await dataProvider.toggleFavorite(row.object)
        } catch {
            // Revert on failure
            if let idx = items.firstIndex(where: { $0.object.uid == originalRow.object.uid }) {
                items[idx] = originalRow
            }
            print("Error toggling favorite for \(row.object.name): \(error)")
        }
    }

    // MARK: - Observation

    private func startObserving() {
        observationTask?.cancel()
        loadingGateTask?.cancel()

        isLoading = true
        let filterForObservation = effectiveFilterForObservation(filter)

        observationTask = Task { [weak self] in
            guard let self else { return }

            var didReceiveFirstEmission = false
            for await rows in self.dataProvider.observeObjects(filter: filterForObservation) {
                didReceiveFirstEmission = true
                await MainActor.run {
                    self.items = rows
                    if !rows.isEmpty {
                        self.isLoading = false
                    }
                }

                if didReceiveFirstEmission, !rows.isEmpty {
                    loadingGateTask?.cancel()
                } else if didReceiveFirstEmission, rows.isEmpty {
                    startLoadingGateIfNeeded()
                }
            }
        }
    }

    private func startLoadingGateIfNeeded() {
        guard loadingGateTask == nil else { return }
        guard let isDatabaseSeeded else {
            isLoading = false
            return
        }

        loadingGateTask = Task { [weak self] in
            guard let self else { return }

            let timeoutNanoseconds: UInt64 = 5_000_000_000
            let pollNanoseconds: UInt64 = 200_000_000
            let start = DispatchTime.now().uptimeNanoseconds

            while !Task.isCancelled {
                if await isDatabaseSeeded() {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }

                let elapsed = DispatchTime.now().uptimeNanoseconds - start
                if elapsed >= timeoutNanoseconds {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: pollNanoseconds)
            }
        }
    }

    private func startLocationUpdates() {
        locationTask?.cancel()

        locationTask = Task { [weak self] in
            guard let self else { return }

            for await location in self.locationProvider.locationStream {
                await MainActor.run {
                    self.currentLocation = location
                }
            }
        }
    }

    private func restartObservation() {
        startObserving()
    }

    // MARK: - Filter Persistence

    private func saveFilter() {
        guard let data = try? JSONEncoder().encode(filter) else { return }
        UserDefaults.standard.set(data, forKey: filterStorageKey)
    }

    private static func loadFilter(key: String) -> Filter? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let filter = try? JSONDecoder().decode(Filter.self, from: data) else {
            return nil
        }
        return filter
    }
}
