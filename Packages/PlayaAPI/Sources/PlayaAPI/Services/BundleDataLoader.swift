import Foundation

/// Service for loading Burning Man API data from resource bundles
///
/// This service provides methods to load JSON data files from bundled resources.
/// It can work with both embedded bundles (like iBurn2025APIData) and fallback
/// to MockAPIData when bundles are not available.
public enum BundleDataLoader {
    
    /// Errors that can occur when loading bundle data
    public enum LoadError: Error, LocalizedError {
        case fileNotFound(String)
        case bundleNotFound
        case invalidData(String)
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Data file not found: \(filename)"
            case .bundleNotFound:
                return "Data bundle not found"
            case .invalidData(let reason):
                return "Invalid data: \(reason)"
            }
        }
    }
    
    /// Load art data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for art installations
    /// - Throws: LoadError if data cannot be loaded
    public static func loadArt(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "art", from: bundle)
    }
    
    /// Load camp data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for camps
    /// - Throws: LoadError if data cannot be loaded
    public static func loadCamps(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "camp", from: bundle)
    }
    
    /// Load event data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for events
    /// - Throws: LoadError if data cannot be loaded
    public static func loadEvents(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "event", from: bundle)
    }
    
    /// Load update info data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for update information
    /// - Throws: LoadError if data cannot be loaded
    public static func loadUpdateInfo(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "update", from: bundle)
    }
    
    /// Load credits data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for credits
    /// - Throws: LoadError if data cannot be loaded
    public static func loadCredits(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "credits", from: bundle)
    }
    
    /// Load dates info data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for date information
    /// - Throws: LoadError if data cannot be loaded
    public static func loadDatesInfo(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "dates_info", from: bundle)
    }
    
    /// Load points data from bundle
    /// - Parameter bundle: Optional bundle to load from. If nil, attempts to find appropriate bundle.
    /// - Returns: JSON data for points of interest
    /// - Throws: LoadError if data cannot be loaded
    public static func loadPoints(from bundle: Bundle? = nil) throws -> Data {
        return try loadDataFile(named: "points", from: bundle)
    }
    
    // MARK: - Private Methods
    
    /// Load a specific data file from the given bundle
    /// - Parameters:
    ///   - filename: The name of the JSON file (without extension)
    ///   - bundle: The bundle to load from
    /// - Returns: The loaded data
    /// - Throws: LoadError if the file cannot be loaded
    private static func loadDataFile(named filename: String, from bundle: Bundle?) throws -> Data {
        let targetBundle = bundle ?? Bundle.main
        
        // First try to find the file in the Resources subdirectory (for iBurn2025APIData bundle)
        var url = targetBundle.url(forResource: filename, withExtension: "json", subdirectory: "Resources")
        
        // If not found in Resources, try the bundle root (for main bundle compatibility)
        if url == nil {
            url = targetBundle.url(forResource: filename, withExtension: "json")
        }
        
        guard let fileURL = url else {
            throw LoadError.fileNotFound("\(filename).json")
        }
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw LoadError.invalidData("Failed to load \(filename).json: \(error.localizedDescription)")
        }
    }
}