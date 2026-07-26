import Foundation

/// The JSON payloads that make up a year's API data, read straight off disk from
/// `data/<year>/APIData/APIData.bundle` rather than through a year-stamped SwiftPM
/// resource bundle — so a new season only needs a `--year` flag, not a code change.
struct APIDataFiles {
    let art: Data
    let camp: Data
    let event: Data
    let mutantVehicle: Data?
    let update: Data?

    /// One object's reference to its remote thumbnail.
    struct ThumbnailReference: Equatable {
        let uid: String
        let remoteURL: URL
    }

    private let directory: URL

    init(directory: URL) throws {
        self.directory = directory

        func read(_ name: String) throws -> Data {
            let url = directory.appendingPathComponent("\(name).json")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SeedError.missingDataFile(url)
            }
            return try Data(contentsOf: url)
        }
        func readIfPresent(_ name: String) -> Data? {
            try? read(name)
        }

        self.art = try read("art")
        self.camp = try read("camp")
        self.event = try read("event")
        // Both are optional in older data years.
        self.mutantVehicle = readIfPresent("mv")
        self.update = readIfPresent("update")
    }

    /// Every thumbnail the API data references, across art, camps and mutant vehicles.
    ///
    /// Objects are keyed by `uid`, matching how the app names cached media
    /// (`<uid>.jpg`) and how `thumbnail_colors.object_id` is keyed.
    func thumbnailReferences() throws -> [ThumbnailReference] {
        try ["art", "camp", "mv"].flatMap { name -> [ThumbnailReference] in
            let url = directory.appendingPathComponent("\(name).json")
            guard let data = try? Data(contentsOf: url) else { return [] }
            return try JSONDecoder().decode([ImageBearingObject].self, from: data)
                .compactMap { object in
                    guard let remote = object.images?.compactMap(\.thumbnailURL).first else { return nil }
                    return ThumbnailReference(uid: object.uid, remoteURL: remote)
                }
        }
    }

    /// Minimal shape shared by art/camp/mv records — just enough to find thumbnails.
    private struct ImageBearingObject: Decodable {
        let uid: String
        let images: [Image]?

        struct Image: Decodable {
            let thumbnailURL: URL?

            private enum CodingKeys: String, CodingKey {
                case thumbnailURL = "thumbnail_url"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // Records can carry null, a malformed URL, or a status placeholder —
                // the org's API uses the literal string "processing" while an upload is
                // still being converted. Treat all of those as "no thumbnail" rather
                // than failing the decode or queuing a download that can't succeed.
                let raw = try? container.decodeIfPresent(String.self, forKey: .thumbnailURL)
                let url = raw.flatMap(URL.init(string:))
                let scheme = url?.scheme?.lowercased()
                self.thumbnailURL = (scheme == "http" || scheme == "https") ? url : nil
            }
        }
    }
}
