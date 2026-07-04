//
//  NearbyScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import MapKit
import PlayaDB
import PlayaGeo
import SwiftUI

struct ObjectRow: Identifiable {
    let object: any DataObject
    let distance: CLLocationDistance?
    var id: String { object.uid }
}

extension DataObjectType {
    var emoji: String {
        switch self {
        case .art: return "🎨"
        case .camp: return "🏕️"
        case .event: return "🎪"
        case .mutantVehicle: return "🚌"
        }
    }
}

func formatDistance(_ meters: CLLocationDistance) -> String {
    meters < 1000 ? "\(Int(meters)) m" : String(format: "%.1f km", meters / 1000)
}

/// Closest art + camps within walking range, sorted by straight-line distance.
struct NearbyScreen: View {
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    @State private var rows: [ObjectRow] = []
    @State private var status: String?

    private static let searchRadiusMeters: CLLocationDistance = 1000

    var body: some View {
        Group {
            if let status {
                Text(status)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            } else {
                List(rows) { row in
                    NavigationLink {
                        DetailScreen(
                            object: row.object,
                            playaDB: playaDB,
                            mapData: mapData,
                            location: location
                        )
                    } label: {
                        HStack {
                            Text(row.object.objectType.emoji)
                            VStack(alignment: .leading) {
                                Text(row.object.name)
                                    .font(.footnote)
                                    .lineLimit(2)
                                if let distance = row.distance {
                                    Text(formatDistance(distance))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Nearby")
        .task(id: location.location) {
            await refresh()
        }
    }

    private func refresh() async {
        guard let userLocation = location.location else {
            status = "Waiting for GPS…"
            return
        }
        do {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: Self.searchRadiusMeters * 2,
                longitudinalMeters: Self.searchRadiusMeters * 2
            )
            async let art = playaDB.fetchArt(filter: ArtFilter(region: region))
            async let camps = playaDB.fetchCamps(filter: CampFilter(region: region))
            let objects: [any DataObject] = try await art + camps

            let sorted = objects
                .compactMap { object -> ObjectRow? in
                    guard let objectLocation = object.location else { return nil }
                    return ObjectRow(object: object, distance: objectLocation.distance(from: userLocation))
                }
                .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
                .prefix(30)

            rows = Array(sorted)
            status = rows.isEmpty
                ? "Nothing nearby yet — camp and art locations unlock when the gates open."
                : nil
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }
}
