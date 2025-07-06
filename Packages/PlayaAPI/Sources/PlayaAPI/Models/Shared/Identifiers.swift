import Foundation

/// Generic strongly-typed identifier
public struct ID<T>: Codable, Hashable, Sendable {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - ExpressibleByStringLiteral

extension ID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

// MARK: - CustomStringConvertible

extension ID: CustomStringConvertible {
    public var description: String { value }
}

// MARK: - Type Aliases

/// Strongly-typed identifier for Art objects
public typealias ArtID = ID<Art>

/// Strongly-typed identifier for Camp objects
public typealias CampID = ID<Camp>

/// Strongly-typed identifier for Event objects
public typealias EventID = ID<Event>