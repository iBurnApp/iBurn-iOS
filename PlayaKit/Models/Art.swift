//
//  Art.swift
//  PlayaKit
//
//  Created by Chris Ballinger on 12/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public class Art: APIObject, ArtProtocol {
    public override var location: PlayaLocation? {
        get {
            return artLocation
        }
        set {
            self.artLocation = newValue as? ArtLocation
        }
    }
    public var artLocation: ArtLocation?
    public var artistName: String = ""
    public var artistHometown: String = ""
    public var donationURL: URL?
    private var imagesLocations: [ImageLocation] = []
    public var images: [URL] {
        return ImageLocation.URLs(imageLocations: imagesLocations)
    }
    
    // MARK: Codable
    public enum CodingKeys: String, CodingKey {
        case artistName = "artist"
        case artistHometown = "hometown"
        case images
        case location
        case donationURL = "donation_link"
    }
    
    public init(title: String,
                year: Int = Calendar.current.component(.year, from: Date()),
                artistName: String,
                artistHometown: String,
                uniqueId: String = UUID().uuidString) {
        self.artistName = artistName
        self.artistHometown = artistHometown
        super.init(title: title, year: year, uniqueId: uniqueId)
    }
    
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let codingKeys = Art.CodingKeys.self
        let container = try decoder.container(keyedBy: codingKeys)
        // Rarely there will be a null artist name or hometown
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName) ?? ""
        artistHometown = try container.decodeIfPresent(String.self, forKey: .artistHometown) ?? ""
        do {
            artLocation = try container.decodeIfPresent(ArtLocation.self, forKey: .location)
        } catch {
            debugPrint("Error decoding artLocation \(error)")
        }
        do {
            donationURL = try container.decodeIfPresent(URL.self, forKey: .donationURL)
        } catch {
            debugPrint("Error decoding donationURL \(error)")
        }
        imagesLocations = try container.decodeIfPresent([ImageLocation].self, forKey: .images) ?? []
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        let codingKeys = Art.CodingKeys.self
        var container = encoder.container(keyedBy: codingKeys)
        try container.encode(artistName, forKey: .artistName)
        try container.encode(artistHometown, forKey: .artistHometown)
        try container.encodeIfPresent(artLocation, forKey: .location)
        try container.encodeIfPresent(donationURL, forKey: .donationURL)
        try container.encode(imagesLocations, forKey: .images)
    }
}

public enum ArtCategory: String {
    case openPlaya = "Open Playa"
    case cafeArt = "Cafe Art"
    case plaza = "Plaza"
    case mobile = "Mobile"
    case keyhole = "Keyhole"
}

private struct ImageLocation: Codable {
    private let thumbnailURLString: String?
    var thumbnailURL: URL? {
        guard let thumbnailURLString = self.thumbnailURLString else { return nil }
        return URL(string: thumbnailURLString)
    }
    static func URLs(imageLocations: [ImageLocation]) -> [URL] {
        return imageLocations.compactMap { $0.thumbnailURL }
    }
    
    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case thumbnailURLString = "thumbnail_url"
    }
}
