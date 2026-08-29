import Foundation

enum SeedError: LocalizedError {
    case missingDataDirectory(URL)
    case missingMediaDirectory(URL)
    case missingDataFile(URL)
    case archiveFailed(String)
    case emptyDatabase

    var errorDescription: String? {
        switch self {
        case .missingDataDirectory(let url):
            return "No API data at \(url.path) — check --year/--data-root, and that the iBurn-Data submodule is checked out (git submodule update --init)."
        case .missingMediaDirectory(let url):
            return "No media bundle at \(url.path) — thumbnails can't be read."
        case .missingDataFile(let url):
            return "Required data file missing: \(url.path)"
        case .archiveFailed(let reason):
            return "Failed to build the seed archive: \(reason)"
        case .emptyDatabase:
            return "Import produced an empty database; refusing to ship an empty seed."
        }
    }
}
