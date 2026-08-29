//
//  ShareURLBuilder.swift
//  iBurn
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 iBurn. All rights reserved.
//

import CoreLocation
import Foundation
import PlayaDB

/// The kinds of objects `iburnapp.com` deep links can address.
///
/// Mirrors `DeepLinkObjectType` in `BRCDeepLinkRouter`, which parses incoming links; the two
/// enums are deliberately the same set of strings so every URL we emit round-trips.
enum ShareURLKind: String {
    case art
    case camp
    case event
    case pin
}

/// The host (camp or art installation) an event hangs off of.
struct ShareURLHost: Equatable {
    let uid: String
    let name: String?
    /// `"camp"` or `"art"` — matches the `host_type` query parameter.
    let kind: String

    static func camp(uid: String, name: String?) -> ShareURLHost {
        ShareURLHost(uid: uid, name: name, kind: "camp")
    }

    static func art(uid: String, name: String?) -> ShareURLHost {
        ShareURLHost(uid: uid, name: name, kind: "art")
    }
}

/// Everything a share URL can carry, already embargo-filtered by the caller.
///
/// Location fields (`coordinate`, `address`) must only be populated when `BRCEmbargo` allows
/// showing that object's placement — the payload factories below take an explicit
/// `canShowLocation` flag rather than reading the embargo state themselves so the rule is
/// testable and impossible to forget at a call site.
struct ShareURLPayload {
    var kind: ShareURLKind
    var uid: String?
    var title: String?
    var coordinate: CLLocationCoordinate2D?
    var address: String?
    var detailDescription: String?
    var startDate: Date?
    var endDate: Date?
    var host: ShareURLHost?
    var isAllDay: Bool = false
    /// `BRCMapPointType` raw value, pin links only.
    var pinType: Int?

    init(
        kind: ShareURLKind,
        uid: String? = nil,
        title: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil,
        address: String? = nil,
        detailDescription: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        host: ShareURLHost? = nil,
        isAllDay: Bool = false,
        pinType: Int? = nil
    ) {
        self.kind = kind
        self.uid = uid
        self.title = title
        self.coordinate = coordinate
        self.address = address
        self.detailDescription = detailDescription
        self.startDate = startDate
        self.endDate = endDate
        self.host = host
        self.isAllDay = isAllDay
        self.pinType = pinType
    }
}

// MARK: - Builder

/// Builds `https://iburnapp.com` universal links for sharing.
///
/// One implementation serves every share surface — legacy YapDB detail screens, the SwiftUI
/// detail screen, map callouts and user pins — so the emitted format can never drift between
/// them and always parses back through `BRCDeepLinkRouter.handleURL(_:)`.
protocol ShareURLBuilder {
    func url(for payload: ShareURLPayload) -> URL?
}

struct ShareURLBuilderImpl: ShareURLBuilder {
    /// Scheme + host of the website that owns the universal link.
    let baseURL: String
    /// Value of the `year` query parameter.
    let year: String
    /// Maximum length of the `desc` parameter (links land in SMS/QR codes).
    let descriptionLimit: Int

    init(
        baseURL: String = "https://iburnapp.com",
        year: String = YearSettings.playaYear,
        descriptionLimit: Int = 100
    ) {
        self.baseURL = baseURL
        self.year = year
        self.descriptionLimit = descriptionLimit
    }

    func url(for payload: ShareURLPayload) -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }

        var queryItems: [URLQueryItem] = []

        switch payload.kind {
        case .art, .camp, .event:
            // Trailing slash matches the website's canonical paths (`/art/`, `/camp/`, `/event/`).
            components.path = "/\(payload.kind.rawValue)/"

            guard let uid = payload.uid, !uid.isEmpty else { return nil }
            queryItems.append(URLQueryItem(name: "uid", value: uid))

            if let title = payload.title, !title.isEmpty {
                queryItems.append(URLQueryItem(name: "title", value: title))
            }

            appendLocation(payload, to: &queryItems)

            if let description = payload.detailDescription, !description.isEmpty {
                let truncated = String(description.prefix(descriptionLimit))
                queryItems.append(URLQueryItem(name: "desc", value: truncated))
            }

            if payload.kind == .event {
                appendEventItems(payload, to: &queryItems)
            }

        case .pin:
            components.path = "/pin"

            guard let coordinate = payload.coordinate else { return nil }
            queryItems.append(URLQueryItem(name: "lat", value: Self.format(coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: Self.format(coordinate.longitude)))

            if let title = payload.title, !title.isEmpty {
                queryItems.append(URLQueryItem(name: "title", value: title))
            }

            if let pinType = payload.pinType {
                queryItems.append(URLQueryItem(name: "type", value: String(pinType)))
            }
        }

        queryItems.append(URLQueryItem(name: "year", value: year))
        components.queryItems = queryItems

        return components.url
    }

    private func appendLocation(_ payload: ShareURLPayload, to queryItems: inout [URLQueryItem]) {
        if let coordinate = payload.coordinate {
            queryItems.append(URLQueryItem(name: "lat", value: Self.format(coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: Self.format(coordinate.longitude)))
        }
        if let address = payload.address, !address.isEmpty {
            queryItems.append(URLQueryItem(name: "addr", value: address))
        }
    }

    private func appendEventItems(_ payload: ShareURLPayload, to queryItems: inout [URLQueryItem]) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]

        if let startDate = payload.startDate {
            queryItems.append(URLQueryItem(name: "start", value: formatter.string(from: startDate)))
        }
        if let endDate = payload.endDate {
            queryItems.append(URLQueryItem(name: "end", value: formatter.string(from: endDate)))
        }
        if let host = payload.host {
            if let name = host.name, !name.isEmpty {
                queryItems.append(URLQueryItem(name: "host", value: name))
            }
            queryItems.append(URLQueryItem(name: "host_id", value: host.uid))
            queryItems.append(URLQueryItem(name: "host_type", value: host.kind))
        }
        if payload.isAllDay {
            queryItems.append(URLQueryItem(name: "all_day", value: "true"))
        }
    }

    private static func format(_ degrees: CLLocationDegrees) -> String {
        String(format: "%.6f", degrees)
    }
}

enum ShareURLBuilderFactory {
    static let shared: ShareURLBuilder = ShareURLBuilderImpl()
}

// MARK: - PlayaDB payloads

extension ShareURLPayload {

    /// - Parameter canShowLocation: `BRCEmbargo.canShowArtLocations()` at the call site.
    static func art(_ art: ArtObject, canShowLocation: Bool) -> ShareURLPayload {
        ShareURLPayload(
            kind: .art,
            uid: art.uid,
            title: art.name,
            coordinate: canShowLocation ? art.location?.coordinate : nil,
            address: canShowLocation ? art.address : nil,
            detailDescription: art.description
        )
    }

    /// - Parameter canShowLocation: `BRCEmbargo.canShowCampLocations()` at the call site.
    static func camp(_ camp: CampObject, canShowLocation: Bool) -> ShareURLPayload {
        ShareURLPayload(
            kind: .camp,
            uid: camp.uid,
            title: camp.name,
            coordinate: canShowLocation ? camp.location?.coordinate : nil,
            address: canShowLocation ? camp.address : nil,
            detailDescription: camp.description
        )
    }

    /// - Parameters:
    ///   - host: Resolved host camp/art, when the event has one.
    ///   - canShowLocation: `BRCEmbargo.canShowLocation(for: event)` at the call site.
    static func event(
        _ event: EventObject,
        startDate: Date? = nil,
        endDate: Date? = nil,
        host: ShareURLHost? = nil,
        canShowLocation: Bool
    ) -> ShareURLPayload {
        ShareURLPayload(
            kind: .event,
            uid: event.uid,
            title: event.name,
            coordinate: canShowLocation ? event.location?.coordinate : nil,
            address: canShowLocation ? eventAddress(otherLocation: event.otherLocation, hostAddress: nil) : nil,
            detailDescription: event.description,
            startDate: startDate,
            endDate: endDate,
            host: host,
            isAllDay: event.allDay
        )
    }

    /// - Parameter canShowLocation: `BRCEmbargo.canShowLocation(for: occurrence)` at the call site.
    static func event(_ occurrence: EventObjectOccurrence, canShowLocation: Bool) -> ShareURLPayload {
        ShareURLPayload(
            kind: .event,
            uid: occurrence.event.uid,
            title: occurrence.name,
            // Events rarely carry their own GPS; fall back to the host camp/art placement.
            coordinate: canShowLocation ? (occurrence.location ?? occurrence.host?.location)?.coordinate : nil,
            address: canShowLocation
                ? eventAddress(otherLocation: occurrence.otherLocation, hostAddress: occurrence.hostAddress)
                : nil,
            detailDescription: occurrence.description,
            startDate: occurrence.startDate,
            endDate: occurrence.endDate,
            host: occurrence.shareHost,
            isAllDay: occurrence.event.allDay
        )
    }

    private static func eventAddress(otherLocation: String, hostAddress: String?) -> String? {
        if !otherLocation.isEmpty { return otherLocation }
        guard let hostAddress, !hostAddress.isEmpty else { return nil }
        return hostAddress
    }
}

extension EventObjectOccurrence {
    /// Host descriptor for share URLs, preferring the camp tier over art (matches `BRCEventObject`).
    var shareHost: ShareURLHost? {
        if let campID = hostedByCamp, !campID.isEmpty {
            return .camp(uid: campID, name: hostName)
        }
        if let artID = locatedAtArt, !artID.isEmpty {
            return .art(uid: artID, name: hostName)
        }
        return nil
    }
}

// MARK: - Legacy payloads

extension ShareURLPayload {

    /// Payload for a legacy YapDB-backed object.
    ///
    /// - Parameters:
    ///   - hostName: Resolved host name for events (looked up asynchronously by the caller).
    ///   - canShowLocation: `BRCEmbargo.canShowLocation(for: object)` at the call site.
    /// - Returns: `nil` for object types that have no deep link (e.g. mutant vehicles).
    static func legacy(_ object: BRCDataObject, hostName: String?, canShowLocation: Bool) -> ShareURLPayload? {
        let kind: ShareURLKind
        if object is BRCArtObject {
            kind = .art
        } else if object is BRCCampObject {
            kind = .camp
        } else if object is BRCEventObject {
            kind = .event
        } else {
            return nil
        }

        var payload = ShareURLPayload(
            kind: kind,
            uid: object.uniqueID,
            title: object.title,
            coordinate: canShowLocation ? object.location?.coordinate : nil,
            address: canShowLocation ? object.playaLocation : nil,
            detailDescription: object.detailDescription
        )

        if let event = object as? BRCEventObject {
            payload.startDate = event.startDate
            payload.endDate = event.endDate
            payload.isAllDay = event.isAllDay
            if let campID = event.hostedByCampUniqueID, !campID.isEmpty {
                payload.host = .camp(uid: campID, name: hostName)
            } else if let artID = event.hostedByArtUniqueID, !artID.isEmpty {
                payload.host = .art(uid: artID, name: hostName)
            }
        }

        return payload
    }
}
