//
//  PinsScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import PlayaDB
import PlayaGeo
import SwiftUI

/// The user's saved pins — bike, home, and anything else they dropped — sorted
/// by how far away they are. Pins sync with the paired phone, so this list also
/// shows pins dropped over there.
struct PinsScreen: View {
    let mapData: PlayaMapData
    @ObservedObject var pinStore: PinStore
    @ObservedObject var location: LocationService

    private var rows: [(pin: UserMapPin, distance: CLLocationDistance?)] {
        let userLocation = location.location
        return pinStore.pins
            .map { pin in (pin, userLocation.map { pin.clLocation.distance(from: $0) }) }
            .sorted { ($0.1 ?? .infinity) < ($1.1 ?? .infinity) }
    }

    var body: some View {
        Group {
            if pinStore.pins.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "mappin.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No pins yet")
                        .font(.footnote)
                    Text("Drop one from the map to remember where you parked.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                List(rows, id: \.pin.id) { row in
                    NavigationLink {
                        PinDetailScreen(
                            pin: row.pin,
                            mapData: mapData,
                            pinStore: pinStore,
                            location: location
                        )
                    } label: {
                        PinRow(pin: row.pin, distance: row.distance)
                    }
                }
            }
        }
        .navigationTitle("Pins")
    }
}

struct PinRow: View {
    let pin: UserMapPin
    let distance: CLLocationDistance?

    var body: some View {
        HStack {
            Image(systemName: pin.type.symbolName)
                .foregroundStyle(pin.type.tint)
                .frame(width: 20)
            VStack(alignment: .leading) {
                Text(pin.displayTitle)
                    .font(.footnote)
                    .lineLimit(2)
                if let distance {
                    Text(formatDistance(distance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A single pin: navigate to it, rename it, or delete it.
struct PinDetailScreen: View {
    let pin: UserMapPin
    let mapData: PlayaMapData
    @ObservedObject var pinStore: PinStore
    @ObservedObject var location: LocationService

    @Environment(\.dismiss) private var dismiss
    @State private var showingRename = false
    @State private var draftTitle = ""
    @State private var showingDeleteConfirmation = false

    /// Follow the stored pin so a rename (or a sync from the phone) is reflected
    /// without leaving the screen; falls back to the value we were pushed with
    /// if it's been deleted out from under us.
    private var current: UserMapPin {
        pinStore.pins.first { $0.id == pin.id } ?? pin
    }

    private var distance: CLLocationDistance? {
        location.location.map { current.clLocation.distance(from: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: current.type.symbolName)
                        .foregroundStyle(current.type.tint)
                    Text(current.displayTitle)
                        .font(.headline)
                }

                if let distance {
                    Text(formatDistance(distance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    NavigationScreen(
                        targetName: current.displayTitle,
                        targetCoordinate: current.coordinate,
                        mapData: mapData,
                        location: location
                    )
                } label: {
                    Label("Navigate", systemImage: "location.north.circle.fill")
                }
                .tint(.orange)

                Button {
                    draftTitle = current.displayTitle
                    showingRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Pin")
        .sheet(isPresented: $showingRename) {
            RenamePinSheet(title: $draftTitle) {
                let newTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                showingRename = false
                guard !newTitle.isEmpty else { return }
                Task { await pinStore.rename(current, to: newTitle) }
            }
        }
        .confirmationDialog(
            "Delete this pin?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await pinStore.delete(current)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct RenamePinSheet: View {
    @Binding var title: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            TextField("Name", text: $title)
            Button("Save", action: onSave)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}

enum PreviewPins {
    /// Two pins a short walk apart, near The Man.
    static let pins: [UserMapPin] = [
        UserMapPin(
            id: "preview-bike",
            title: "Bike",
            latitude: 40.7874,
            longitude: -119.2055,
            pinType: UserMapPinType.userBike.rawValue
        ),
        UserMapPin(
            id: "preview-home",
            title: "Home",
            latitude: 40.7840,
            longitude: -119.2100,
            pinType: UserMapPinType.userHome.rawValue
        )
    ]
}

#Preview("Pins") {
    NavigationStack {
        PinsScreen(
            mapData: PreviewMapData.data,
            pinStore: PinStore(previewPins: PreviewPins.pins),
            location: LocationService()
        )
    }
}

#Preview("No pins") {
    NavigationStack {
        PinsScreen(
            mapData: PreviewMapData.data,
            pinStore: PinStore(previewPins: []),
            location: LocationService()
        )
    }
}

/// Type picker for dropping a pin at the user's current location.
struct DropPinSheet: View {
    let coordinate: CLLocationCoordinate2D?
    @ObservedObject var pinStore: PinStore
    let onDropped: (UserMapPinType) -> Void

    var body: some View {
        Group {
            if let coordinate {
                List(UserMapPinType.userCreatable, id: \.rawValue) { type in
                    Button {
                        Task { await pinStore.addPin(type: type, coordinate: coordinate) }
                        onDropped(type)
                    } label: {
                        // Not a Label: a button's tint doesn't reach the
                        // symbol, so the icon is styled directly to match the
                        // colors used in the pins list and on the map.
                        HStack {
                            Image(systemName: type.symbolName)
                                .foregroundStyle(type.tint)
                                .frame(width: 20)
                            Text(type.displayName)
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "location.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Waiting for GPS…")
                        .font(.footnote)
                    Text("A pin needs your location to be worth anything.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Drop Pin")
    }
}
