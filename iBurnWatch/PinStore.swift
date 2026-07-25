//
//  PinStore.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import PlayaDB
import SwiftUI

/// Live view of the user's map pins, shared by the map and the pins list.
///
/// State comes from the GRDB observation only — writes go to PlayaDB and the
/// observation delivers the result. That also means pins arriving from the
/// paired phone appear here with no extra plumbing.
@MainActor
final class PinStore: ObservableObject {
    @Published private(set) var pins: [UserMapPin] = []

    private let playaDB: PlayaDB?
    private var observation: PlayaDBObservationToken?

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
        observation = playaDB.observeUserMapPins { [weak self] pins in
            Task { @MainActor in
                self?.pins = pins
            }
        }
    }

    /// Preview seam: fixed pins, no database. Writes are no-ops.
    init(previewPins: [UserMapPin]) {
        self.playaDB = nil
        self.pins = previewPins
    }

    /// Drops a new pin of `type` at `coordinate`, titled after the type.
    func addPin(type: UserMapPinType, coordinate: CLLocationCoordinate2D) async {
        let pin = UserMapPin(
            title: type.displayName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pinType: type.rawValue
        )
        await save(pin)
    }

    func rename(_ pin: UserMapPin, to title: String) async {
        var updated = pin
        updated.title = title
        updated.modifiedDate = Date()
        await save(updated)
    }

    func delete(_ pin: UserMapPin) async {
        guard let playaDB else { return }
        do {
            try await playaDB.deleteUserMapPin(id: pin.id)
        } catch {
            print("PinStore: delete failed: \(error)")
        }
    }

    private func save(_ pin: UserMapPin) async {
        guard let playaDB else { return }
        do {
            try await playaDB.saveUserMapPin(pin)
        } catch {
            print("PinStore: save failed: \(error)")
        }
    }
}

// MARK: - Display helpers

extension UserMapPin {
    var type: UserMapPinType {
        UserMapPinType(pinTypeString: pinType)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Pins are titled after their type by default; fall back if that's blank.
    var displayTitle: String {
        guard let title, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return type.displayName
        }
        return title
    }
}

extension UserMapPinType {
    var tint: Color {
        switch self {
        case .userBike: return .green
        case .userHome: return .orange
        case .userStar: return .yellow
        case .userCamp: return .teal
        case .userHeart: return .pink
        case .userBreadcrumb: return .gray
        case .toilet: return .blue
        case .medical: return .red
        case .ranger: return .indigo
        }
    }
}
