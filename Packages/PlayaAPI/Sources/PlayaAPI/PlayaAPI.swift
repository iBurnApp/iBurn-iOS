import Foundation

/// Main PlayaAPI module providing access to all API models and services
public enum PlayaAPI {
    /// Creates a JSONDecoder configured for Burning Man API data
    public static func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    /// Creates a JSONEncoder configured for Burning Man API data
    public static func createEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}