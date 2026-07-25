//
//  VisiblePinsViewModel.swift
//  iBurn
//
//  PlayaDB-native backing for the map's "Visible Pins" list.
//

import CoreLocation
import Foundation
import MapLibre
import PlayaDB

// MARK: - Item

/// One row in the map contents list.
///
/// Everything here is resolved straight off the annotations already on the map
/// (`PlayaObjectAnnotation.object` / `BRCUserMapPoint`), so the list needs no
/// database round trip to render.
enum VisiblePinItem: Identifiable {
    case art(ArtObject)
    case camp(CampObject)
    case eventOccurrence(EventObjectOccurrence)
    /// Degraded case for annotations built from a bare `EventObject` (e.g. a detail-screen map).
    case event(EventObject)
    case userPin(BRCUserMapPoint)

    var id: String {
        switch self {
        case .art(let o): return "art:\(o.uid)"
        case .camp(let o): return "camp:\(o.uid)"
        case .eventOccurrence(let o): return "event:\(o.event.uid)"
        case .event(let o): return "event:\(o.uid)"
        case .userPin(let p): return "pin:\(p.pinId)"
        }
    }

    var name: String {
        switch self {
        case .art(let o): return o.name
        case .camp(let o): return o.name
        case .eventOccurrence(let o): return o.name
        case .event(let o): return o.name
        case .userPin(let p):
            let title = p.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let title, !title.isEmpty { return title }
            return p.type.pinDisplayName
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let o): return o.location
        case .camp(let o): return o.location
        case .eventOccurrence(let o): return o.location
        case .event(let o): return o.location
        case .userPin(let p): return p.location()
        }
    }

    /// UID used for favorite lookups. `getFavorites()` returns base `EventObject`s,
    /// so events key off the event uid rather than the occurrence uid.
    var favoriteUID: String? {
        switch self {
        case .art(let o): return o.uid
        case .camp(let o): return o.uid
        case .eventOccurrence(let o): return o.event.uid
        case .event(let o): return o.uid
        case .userPin: return nil
        }
    }

    /// Detail screen to push on tap. User pins have no detail screen.
    var detailSubject: DetailSubject? {
        switch self {
        case .art(let o): return .art(o)
        case .camp(let o): return .camp(o)
        case .eventOccurrence(let o): return .eventOccurrence(o)
        case .event(let o): return .event(o)
        case .userPin: return nil
        }
    }
}

// MARK: - Section

struct VisiblePinSection: Identifiable {
    let id: String
    let title: String
    let items: [VisiblePinItem]
}

// MARK: - View Model

/// Lists the PlayaDB objects and user pins currently drawn on a map view.
///
/// The annotation array is a snapshot taken when the list is opened — this screen is a
/// "what's on screen right now" readout, so it deliberately does not observe the map.
@MainActor
final class VisiblePinsViewModel: ObservableObject {

    // MARK: Published

    @Published private(set) var favoriteUIDs: Set<String> = []
    @Published private(set) var currentLocation: CLLocation?

    // MARK: Dependencies

    private let playaDB: PlayaDB
    private let favoriteSync: FavoriteSyncService
    private let locationProvider: LocationProvider

    // MARK: State

    private let artItems: [VisiblePinItem]
    private let campItems: [VisiblePinItem]
    private let eventItems: [VisiblePinItem]
    private let pinItems: [VisiblePinItem]

    private var locationTask: Task<Void, Never>?
    private var favoritesTask: Task<Void, Never>?

    // MARK: Init

    init(
        annotations: [MLNAnnotation],
        playaDB: PlayaDB,
        locationProvider: LocationProvider,
        favoriteSync: FavoriteSyncService = FavoriteSyncServiceFactory.shared
    ) {
        self.playaDB = playaDB
        self.locationProvider = locationProvider
        self.favoriteSync = favoriteSync
        self.currentLocation = locationProvider.currentLocation

        var art: [VisiblePinItem] = []
        var camps: [VisiblePinItem] = []
        var events: [VisiblePinItem] = []
        var pins: [VisiblePinItem] = []
        var seen = Set<String>()

        for annotation in annotations {
            let item: VisiblePinItem?
            if let playaObject = (annotation as? PlayaObjectAnnotation)?.object {
                switch playaObject {
                case .art(let o): item = .art(o)
                case .camp(let o): item = .camp(o)
                case .eventOccurrence(let o): item = .eventOccurrence(o)
                case .event(let o): item = .event(o)
                }
            } else if let pin = annotation as? BRCUserMapPoint {
                item = .userPin(pin)
            } else {
                item = nil
            }

            guard let item, seen.insert(item.id).inserted else { continue }

            switch item {
            case .art: art.append(item)
            case .camp: camps.append(item)
            case .eventOccurrence, .event: events.append(item)
            case .userPin: pins.append(item)
            }
        }

        self.artItems = art
        self.campItems = camps
        self.eventItems = events
        self.pinItems = pins

        startLocationUpdates()
        loadFavorites()
    }

    deinit {
        locationTask?.cancel()
        favoritesTask?.cancel()
    }

    // MARK: Sections

    var sections: [VisiblePinSection] {
        var result: [VisiblePinSection] = []
        if !artItems.isEmpty {
            result.append(VisiblePinSection(id: "art", title: "Art", items: sorted(artItems)))
        }
        if !campItems.isEmpty {
            result.append(VisiblePinSection(id: "camp", title: "Camps", items: sorted(campItems)))
        }
        if !eventItems.isEmpty {
            result.append(VisiblePinSection(id: "event", title: "Events", items: sorted(eventItems)))
        }
        if !pinItems.isEmpty {
            result.append(VisiblePinSection(id: "pin", title: "Map Pins", items: sorted(pinItems)))
        }
        return result
    }

    var isEmpty: Bool {
        artItems.isEmpty && campItems.isEmpty && eventItems.isEmpty && pinItems.isEmpty
    }

    /// Nearest-first when a user location is available, alphabetical otherwise.
    private func sorted(_ items: [VisiblePinItem]) -> [VisiblePinItem] {
        guard let location = currentLocation else {
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return items.sorted { a, b in
            let distanceA = a.location.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
            let distanceB = b.location.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
            if distanceA == distanceB {
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return distanceA < distanceB
        }
    }

    // MARK: Display helpers

    /// Walk/bike estimate string, matching the other PlayaDB list screens.
    func distanceString(for item: VisiblePinItem) -> AttributedString? {
        guard let location = currentLocation,
              let itemLocation = item.location,
              let formatted = TTTLocationFormatter.brc_humanizedString(forDistance: location.distance(from: itemLocation)) else {
            return nil
        }
        return AttributedString(formatted)
    }

    func isFavorite(_ item: VisiblePinItem) -> Bool {
        guard let uid = item.favoriteUID else { return false }
        return favoriteUIDs.contains(uid)
    }

    // MARK: Favorites

    func toggleFavorite(_ item: VisiblePinItem) async {
        guard let uid = item.favoriteUID else { return }

        // Each case calls through concretely: the existential spelling
        // `any DataObject` is unusable here because `DataObject` resolves to the
        // legacy `iBurn.DataObject` class and `PlayaDB.DataObject` parses as a
        // member of the same-named `PlayaDB` protocol.
        do {
            let mirrorType: FavoriteSyncObjectType
            let isFavorite: Bool
            switch item {
            case .art(let o):
                mirrorType = .art
                try await playaDB.toggleFavorite(o)
                isFavorite = try await playaDB.isFavorite(o)
            case .camp(let o):
                mirrorType = .camp
                try await playaDB.toggleFavorite(o)
                isFavorite = try await playaDB.isFavorite(o)
            case .eventOccurrence(let o):
                mirrorType = .event
                try await playaDB.toggleFavorite(o)
                isFavorite = try await playaDB.isFavorite(o)
            case .event(let o):
                mirrorType = .event
                try await playaDB.toggleFavorite(o)
                isFavorite = try await playaDB.isFavorite(o)
            case .userPin:
                return
            }

            if isFavorite {
                favoriteUIDs.insert(uid)
            } else {
                favoriteUIDs.remove(uid)
            }
            // Fire-and-forget mirror into legacy YapDatabase; PlayaDB is the source of truth.
            let favoriteSync = self.favoriteSync
            Task {
                await favoriteSync.mirrorFavorite(type: mirrorType, uid: uid, isFavorite: isFavorite)
            }
        } catch {
            print("Error toggling favorite for \(item.name): \(error)")
        }
    }

    private func loadFavorites() {
        favoritesTask?.cancel()
        favoritesTask = Task { [weak self] in
            guard let self else { return }
            guard let favorites = try? await self.playaDB.getFavorites() else { return }
            self.favoriteUIDs = Set(favorites.map(\.uid))
        }
    }

    // MARK: Location

    private func startLocationUpdates() {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            for await location in self.locationProvider.locationStream {
                self.currentLocation = location
            }
        }
    }
}

// MARK: - Pin type display

extension BRCMapPointType {
    /// Human-readable name for a user-dropped pin, used when the pin has no title.
    var pinDisplayName: String {
        switch self {
        case .userHome: return "Home"
        case .userBike: return "Bike"
        case .userCamp: return "Camp"
        case .userHeart: return "Favorite"
        case .userBreadcrumb: return "Breadcrumb"
        case .toilet: return "Toilet"
        case .medical: return "Medical"
        case .ranger: return "Ranger"
        case .userStar, .unknown: return "Starred Location"
        @unknown default: return "Starred Location"
        }
    }
}
