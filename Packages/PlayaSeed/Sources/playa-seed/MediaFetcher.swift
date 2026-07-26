import Foundation

/// Downloads thumbnails that the API data references but the media bundle doesn't have.
///
/// Replaces `scripts/BlackRockCityPlanner/src/art_image_download.js` in iBurn-Data,
/// which has been unusable since the org moved image hosting to HTTPS (that script
/// uses Node's `http` module) and only ever covered art.
struct MediaFetcher {
    let destination: URL
    /// Concurrent downloads. Kept modest — this hits the org's CDN.
    var maxConcurrent = 6

    struct Result {
        var downloaded: [String] = []
        var failed: [(uid: String, error: String)] = []
    }

    func fetch(_ references: [APIDataFiles.ThumbnailReference]) async -> Result {
        guard !references.isEmpty else { return Result() }

        var result = Result()
        // Bounded task group: keep at most `maxConcurrent` requests in flight.
        await withTaskGroup(of: (String, String?).self) { group in
            var index = 0
            func addTask() {
                guard index < references.count else { return }
                let reference = references[index]
                index += 1
                group.addTask {
                    do {
                        let (data, response) = try await URLSession.shared.data(from: reference.remoteURL)
                        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                            return (reference.uid, "HTTP \(http.statusCode)")
                        }
                        guard !data.isEmpty else { return (reference.uid, "empty response") }
                        let file = destination.appendingPathComponent("\(reference.uid).jpg")
                        try data.write(to: file, options: .atomic)
                        return (reference.uid, nil)
                    } catch {
                        return (reference.uid, error.localizedDescription)
                    }
                }
            }

            for _ in 0..<min(maxConcurrent, references.count) { addTask() }

            while let (uid, error) = await group.next() {
                if let error {
                    result.failed.append((uid, error))
                } else {
                    result.downloaded.append(uid)
                }
                addTask()
            }
        }
        return result
    }
}
