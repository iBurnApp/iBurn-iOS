//
//  EventListScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import PlayaAPI
import PlayaDB
import PlayaGeo
import SwiftUI

/// Events grouped by festival day: a horizontally scrolling day picker on top,
/// the selected day's occurrences (in start-time order) below. Subscribes once
/// with a full-festival filter so day switching never re-hits the database.
struct EventListScreen: View {
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    @State private var sectionsByDay: [Date: [EventHourSection]] = [:]
    @State private var selectedDay: Date?
    @State private var loaded = false
    @State private var loadError: Error?
    /// Held in @State so the GRDB observation stays alive for the lifetime of
    /// this screen; dropping the token cancels the observation.
    @State private var observationToken: PlayaDBObservationToken?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEd")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private var days: [Date] {
        sectionsByDay.keys.sorted()
    }

    private var selectedRows: [ListRow<EventObjectOccurrence>] {
        guard let selectedDay, let sections = sectionsByDay[selectedDay] else { return [] }
        return sections.flatMap(\.rows)
    }

    var body: some View {
        Group {
            if loaded, let loadError {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Couldn't load events")
                        .font(.footnote)
                    Text(loadError.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if !loaded {
                ProgressView()
            } else if days.isEmpty {
                Text("No events yet")
                    .font(.footnote)
            } else {
                VStack(spacing: 0) {
                    dayPicker
                    List(selectedRows, id: \.object.uid) { row in
                        NavigationLink {
                            DetailScreen(
                                object: row.object.event,
                                playaDB: playaDB,
                                mapData: mapData,
                                location: location
                            )
                        } label: {
                            VStack(alignment: .leading) {
                                Text(row.object.name)
                                    .font(.footnote)
                                    .lineLimit(2)
                                Text("\(Self.timeFormatter.string(from: row.object.startDate)) (\(row.object.durationString))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Events")
        .task {
            startObserving()
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    Button {
                        selectedDay = day
                    } label: {
                        Text(Self.dayFormatter.string(from: day))
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(
                                    day == selectedDay ? Color.accentColor : Color.gray.opacity(0.3)
                                )
                            )
                            .foregroundStyle(day == selectedDay ? .black : .white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func startObserving() {
        guard observationToken == nil else { return }
        let filter = makeFilter()
        observationToken = playaDB.observeEventsByDayThenHour(filter: filter) { bucket in
            DispatchQueue.main.async {
                sectionsByDay = bucket
                if selectedDay.flatMap({ bucket[$0] }) == nil {
                    let today = Calendar.current.startOfDay(for: Date())
                    selectedDay = bucket[today] != nil ? today : bucket.keys.sorted().first
                }
                loadError = nil
                loaded = true
            }
        } onError: { error in
            DispatchQueue.main.async {
                loadError = error
                loaded = true
            }
        }
    }

    /// Full-festival filter, with "Mature Audiences" (`adlt`) events excluded
    /// unless the user is physically on playa. Mirrors the phone's
    /// `EventFilter.excludingAdultEvents()` in RegionStatusService.swift (that
    /// file lives in the iOS target, so the gate is replicated here). Because
    /// `eventTypeCodes` is an inclusion list, "all types" becomes "every known
    /// API type except adlt". Computed once at screen load.
    private func makeFilter() -> EventFilter {
        var filter = EventFilter()
        if !isOnPlaya() {
            var codes = Set(EventType.allCases.map(\.rawValue))
            codes.remove(EventType.matureAudiences.rawValue)
            filter.eventTypeCodes = codes
        }
        return filter
    }

    /// On-playa when the current GPS fix projects inside the playa radius;
    /// no fix means not on playa.
    private func isOnPlaya() -> Bool {
        guard let coordinate = location.location?.coordinate else { return false }
        return mapData.pointOnPlaya(
            for: GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) != nil
    }
}
