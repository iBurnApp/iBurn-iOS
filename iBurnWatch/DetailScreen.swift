//
//  DetailScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import PlayaDB
import PlayaGeo
import SwiftUI

struct DetailScreen: View {
    let object: any DataObject
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService
    var onFavoriteChange: () -> Void = {}

    @State private var isFavorite = false
    @State private var visitStatus: VisitStatus = .unvisited
    @State private var showingVisitStatusPicker = false
    @State private var occurrences: [EventObjectOccurrence] = []

    private var locationIsUnlocked: Bool {
        WatchEmbargo.canShowLocation(for: object)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(object.objectType.emoji)
                    Text(object.name)
                        .font(.headline)
                }

                Button {
                    Task {
                        do {
                            try await playaDB.setFavorite(!isFavorite, for: object)
                            isFavorite.toggle()
                            onFavoriteChange()
                        } catch {
                            print("Favorite toggle failed: \(error)")
                        }
                    }
                } label: {
                    Label(
                        isFavorite ? "Remove Favorite" : "Add Favorite",
                        systemImage: isFavorite ? "heart.fill" : "heart"
                    )
                }
                .tint(isFavorite ? .red : nil)

                // Menu is unavailable on watchOS, so the visit-status control
                // is a button that presents a selection sheet.
                Button {
                    showingVisitStatusPicker = true
                } label: {
                    Label(visitStatus.displayString, systemImage: visitStatus.iconName)
                }
                .tint(visitStatus.tint)
                .sheet(isPresented: $showingVisitStatusPicker) {
                    List(VisitStatus.allCases, id: \.rawValue) { status in
                        Button {
                            setVisitStatus(status)
                            showingVisitStatusPicker = false
                        } label: {
                            HStack {
                                Label(status.displayString, systemImage: status.iconName)
                                Spacer()
                                if status == visitStatus {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    .navigationTitle("Visit Status")
                }

                // Navigate plots the object as a labelled marker with a live
                // distance/bearing readout, so it is the most direct leak of an
                // embargoed coordinate on the watch. Two different reasons it
                // can be missing, and the copy no longer conflates them.
                if !locationIsUnlocked {
                    Text("Location hidden until gates open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if object.hasLocation {
                    NavigationLink {
                        NavigationScreen(
                            target: object,
                            mapData: mapData,
                            location: location
                        )
                    } label: {
                        Label("Navigate", systemImage: "location.north.circle.fill")
                    }
                    .tint(.orange)
                } else {
                    Text("No location available")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !occurrences.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(occurrences, id: \.uid) { occurrence in
                            Text(occurrenceText(occurrence))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let description = object.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(object.objectType.displayName)
        .task {
            isFavorite = (try? await playaDB.isFavorite(object)) ?? false
            if let metadata = try? await playaDB.metadata(for: object) {
                visitStatus = metadata.visitStatusValue
            }
            if object.objectType == .event {
                let all = ((try? await playaDB.fetchOccurrences(forEventUID: object.uid)) ?? [])
                    .sorted { $0.startDate < $1.startDate }
                let now = Date()
                let upcoming = all.filter { $0.endDate >= now }
                occurrences = Array((upcoming.isEmpty ? all : upcoming).prefix(5))
            }
        }
    }

    private func setVisitStatus(_ status: VisitStatus) {
        Task {
            do {
                try await playaDB.setVisitStatus(status, for: object)
                visitStatus = status
                onFavoriteChange()
            } catch {
                print("Visit status update failed: \(error)")
            }
        }
    }

    /// Formats an occurrence as e.g. "Wed 12:00–2:00 PM".
    private func occurrenceText(_ occurrence: EventObjectOccurrence) -> String {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")
        let intervalFormatter = DateIntervalFormatter()
        intervalFormatter.dateStyle = .none
        intervalFormatter.timeStyle = .short
        let weekday = weekdayFormatter.string(from: occurrence.startDate)
        let times = intervalFormatter.string(from: occurrence.startDate, to: occurrence.endDate)
        return "\(weekday) \(times)"
    }
}

/// Display strings, icons, and tints matching the iPhone app's `BRCVisitStatus`.
private extension VisitStatus {
    var displayString: String {
        switch self {
        case .unvisited: return "Not Visited"
        case .visited: return "Visited"
        case .wantToVisit: return "Want to Visit"
        }
    }

    var iconName: String {
        switch self {
        case .unvisited: return "circle"
        case .visited: return "checkmark.circle.fill"
        case .wantToVisit: return "star.fill"
        }
    }

    var tint: Color? {
        switch self {
        case .unvisited: return nil
        case .visited: return .green
        case .wantToVisit: return .yellow
        }
    }
}

/// Compass navigation to a single point: map fit to you + the target, heading-up
/// when the compass is available, with live distance/bearing readout.
/// Takes a bare name + coordinate so it serves both database objects and
/// user-placed pins.
struct NavigationScreen: View {
    let targetName: String
    let targetCoordinate: CLLocationCoordinate2D?
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    init(
        targetName: String,
        targetCoordinate: CLLocationCoordinate2D?,
        mapData: PlayaMapData,
        location: LocationService
    ) {
        self.targetName = targetName
        self.targetCoordinate = targetCoordinate
        self.mapData = mapData
        self.location = location
    }

    init(target: any DataObject, mapData: PlayaMapData, location: LocationService) {
        self.init(
            targetName: target.name,
            targetCoordinate: target.location?.coordinate,
            mapData: mapData,
            location: location
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let targetPoint = targetWorldPoint
            let userPoint = userWorldPoint

            ZStack(alignment: .bottom) {
                PlayaMapView(
                    data: mapData,
                    camera: camera(viewport: geometry.size, user: userPoint, target: targetPoint),
                    user: userPoint.map {
                        PlayaMapView.UserState(point: $0, headingDegrees: location.headingDegrees)
                    },
                    markers: targetPoint.map {
                        [MapMarker(id: "target", point: $0, label: targetName, color: .red)]
                    } ?? []
                )
                .ignoresSafeArea()

                if let readout {
                    Text(readout)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.65), in: Capsule())
                }
            }
            .overlay(alignment: .top) {
                if location.needsCalibration {
                    Text("Wave your wrist in a figure-8 to calibrate")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .padding(4)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onAppear { location.start() }
        .navigationTitle("Navigate")
    }

    private var targetWorldPoint: CGPoint? {
        guard let targetCoordinate else { return nil }
        return mapData.projection.point(
            for: GeoCoordinate(
                latitude: targetCoordinate.latitude,
                longitude: targetCoordinate.longitude
            )
        )
    }

    private var userWorldPoint: CGPoint? {
        guard let userLocation = location.location else { return nil }
        return mapData.pointOnPlaya(
            for: GeoCoordinate(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude
            )
        )
    }

    private func camera(viewport: CGSize, user: CGPoint?, target: CGPoint?) -> MapCamera {
        var points = [CGPoint]()
        if let user { points.append(user) }
        if let target { points.append(target) }
        if points.isEmpty { points = mapData.cityBounds }
        var cam = MapCamera.fitting(points: points, viewport: viewport, paddingFraction: 0.22, minMetersPerPoint: 1)
        if let heading = location.headingDegrees {
            cam.headingDegrees = heading
        }
        return cam
    }

    private var readout: String? {
        guard let user = userWorldPoint, let target = targetWorldPoint else { return nil }
        let dx = Double(target.x - user.x)
        let dy = Double(target.y - user.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        // World +y is south, so north = -dy.
        var bearing = atan2(dx, -dy) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return "\(formatDistance(distance)) · \(Int(bearing.rounded()))°"
    }
}
