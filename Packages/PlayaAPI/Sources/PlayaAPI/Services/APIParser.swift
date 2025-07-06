import Foundation

/// Protocol for parsing Burning Man API JSON data
public protocol APIParserProtocol {
    /// Parse an array of Art objects from JSON data
    func parseArt(from data: Data) throws -> [Art]
    
    /// Parse an array of Camp objects from JSON data
    func parseCamps(from data: Data) throws -> [Camp]
    
    /// Parse an array of Event objects from JSON data
    func parseEvents(from data: Data) throws -> [Event]
    
    /// Parse UpdateInfo from JSON data
    func parseUpdateInfo(from data: Data) throws -> UpdateInfo
}

/// Factory for creating API parser instances
public enum APIParserFactory {
    /// Create a new API parser instance
    public static func create(decoder: JSONDecoder = PlayaAPI.createDecoder()) -> APIParserProtocol {
        APIParserImpl(decoder: decoder)
    }
}

// MARK: - Internal Implementation

struct APIParserImpl: APIParserProtocol {
    private let decoder: JSONDecoder
    
    init(decoder: JSONDecoder) {
        self.decoder = decoder
    }
    
    func parseArt(from data: Data) throws -> [Art] {
        try decoder.decode([Art].self, from: data)
    }
    
    func parseCamps(from data: Data) throws -> [Camp] {
        try decoder.decode([Camp].self, from: data)
    }
    
    func parseEvents(from data: Data) throws -> [Event] {
        try decoder.decode([Event].self, from: data)
    }
    
    func parseUpdateInfo(from data: Data) throws -> UpdateInfo {
        try decoder.decode(UpdateInfo.self, from: data)
    }
}