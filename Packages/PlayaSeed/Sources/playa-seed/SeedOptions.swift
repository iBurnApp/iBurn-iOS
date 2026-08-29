import Foundation

/// Parsed command-line options for `playa-seed`.
struct SeedOptions {
    var year: Int
    /// Repository root; every default path is derived from this.
    var repositoryRoot: URL
    /// Directory holding `APIData/` and `MediaFiles/` for `year`.
    var dataRoot: URL
    /// Destination `.zip`s, each containing a single `PlayaDB.sqlite` entry. Defaults to
    /// one per app target — the phone and the watch each restore from their own bundle.
    var outputs: [URL]
    /// Download thumbnails the API references but the media bundle is missing.
    var fetchMedia: Bool
    /// Skip colour extraction (much faster; used when only the data matters).
    var skipColors: Bool

    static let usage = """
    USAGE: playa-seed [options]

    Builds a pre-populated PlayaDB.sqlite — API data imported and thumbnail colours
    extracted — and zips it for the app to restore on first launch, so a fresh install
    doesn't have to import JSON or compute colours on device.

    OPTIONS:
      --year <year>        Data year to build (default: 2026)
      --repo-root <path>   iBurn-iOS checkout (default: inferred from the executable,
                           falling back to the current directory)
      --data-root <path>   Overrides Submodules/iBurn-Data/data/<year>
      --output <path>      Output zip; repeatable. Defaults to both app targets:
                           <repo-root>/iBurn/PlayaDB-<year>.zip
                           <repo-root>/iBurnWatch/PlayaDB-<year>.zip
      --fetch-media        Download thumbnails missing from the media bundle first
      --skip-colors        Import data only; leave thumbnail_colors empty
      --help               Show this message
    """

    struct ParseError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Parses `arguments` (without the executable name).
    static func parse(_ arguments: [String]) throws -> SeedOptions? {
        var year = 2026
        var repositoryRoot: URL?
        var dataRoot: URL?
        var outputs: [URL] = []
        var fetchMedia = false
        var skipColors = false

        var index = arguments.startIndex
        func nextValue(for flag: String) throws -> String {
            index += 1
            guard index < arguments.endIndex else {
                throw ParseError(message: "Missing value for \(flag)")
            }
            return arguments[index]
        }

        while index < arguments.endIndex {
            let argument = arguments[index]
            switch argument {
            case "--help", "-h":
                return nil
            case "--year":
                let value = try nextValue(for: argument)
                guard let parsed = Int(value), parsed > 2000, parsed < 3000 else {
                    throw ParseError(message: "Invalid year: \(value)")
                }
                year = parsed
            case "--repo-root":
                repositoryRoot = URL(fileURLWithPath: try nextValue(for: argument)).standardizedFileURL
            case "--data-root":
                dataRoot = URL(fileURLWithPath: try nextValue(for: argument)).standardizedFileURL
            case "--output":
                outputs.append(URL(fileURLWithPath: try nextValue(for: argument)).standardizedFileURL)
            case "--fetch-media":
                fetchMedia = true
            case "--skip-colors":
                skipColors = true
            default:
                throw ParseError(message: "Unknown argument: \(argument)\n\n\(usage)")
            }
            index += 1
        }

        let root = repositoryRoot ?? inferRepositoryRoot()
        return SeedOptions(
            year: year,
            repositoryRoot: root,
            dataRoot: dataRoot ?? root
                .appendingPathComponent("Submodules/iBurn-Data/data")
                .appendingPathComponent("\(year)"),
            outputs: outputs.isEmpty
                ? ["iBurn", "iBurnWatch"].map {
                    root.appendingPathComponent($0).appendingPathComponent("PlayaDB-\(year).zip")
                }
                : outputs,
            fetchMedia: fetchMedia,
            skipColors: skipColors
        )
    }

    /// Walks up from the executable (…/Packages/PlayaSeed/.build/…) looking for the
    /// checkout, so `swift run` works from anywhere. Falls back to the working directory.
    private static func inferRepositoryRoot() -> URL {
        let marker = "iBurn.xcworkspace"
        var candidate = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()

        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent(marker).path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - Derived paths

    var apiDataDirectory: URL {
        dataRoot.appendingPathComponent("APIData/APIData.bundle")
    }

    var mediaDirectory: URL {
        dataRoot.appendingPathComponent("MediaFiles/MediaFiles.bundle")
    }
}
