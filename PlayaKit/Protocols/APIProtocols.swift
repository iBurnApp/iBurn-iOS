//
//  APIProtocol.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 9/30/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public enum DecodeError: Error {
    case dateFormatting
}

public protocol APIProtocol {
    /// unique 'uid' returned from PlayaEvents API
    var uniqueId: String { get }
    var title: String { get }
    var detailDescription: String? { get }
    var email: String? { get }
    var url: URL? { get }
    var location: PlayaLocation? { get }
    var year: Int { get }
}

public protocol CampProtocol: APIProtocol {
    var campLocation: CampLocation? { get }
    var burnerMapLocation: CampLocation? { get }
    var hometown: String? { get }
}

public protocol ArtProtocol: APIProtocol {
    var artLocation: ArtLocation? { get }
    var artistName: String { get }
    var artistHometown: String { get }
    var images: [URL] { get }
    var donationURL: URL? { get }
    /// e.g. "Open Playa", "Cafe Art", "Plaza", or "Mobile"
    // var category: ArtCategory { get }
}

public protocol EventProtocol: APIProtocol {
    var hostedByCamp: String? { get }
    var hostedByArt: String? { get }
    var occurrences: [EventOccurrence] { get }
    var eventType: EventType { get }
}
