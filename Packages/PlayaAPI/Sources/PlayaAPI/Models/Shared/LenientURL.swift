import Foundation

/// Decoding utilities for user-entered URL strings.
///
/// Burning Man API `url` fields are free-text entered by camp/art/vehicle leads and
/// routinely contain junk: multiple URLs separated by commas, stray page titles,
/// missing schemes, or plain prose ("Come visit us at the corner!"). Decoding these
/// strictly as `URL` throws `DecodingError.dataCorrupted`, which — because the whole
/// import runs in a single database transaction — rolls back *every* record and leaves
/// the app with an empty database. These helpers decode such fields tolerantly instead:
/// a present-but-garbage value salvages a best-effort URL or resolves to `nil`, and
/// never throws.
public enum LenientURL {
    /// Parses a user-entered URL string tolerantly.
    ///
    /// Resolution order:
    /// 1. The trimmed string as-is, when it is a single clean token (no embedded commas
    ///    or whitespace) that already reads as a real web URL (scheme + host).
    /// 2. Salvage: split on commas/whitespace and return the first token that parses as
    ///    a web URL, accepting a bare `www.*` token by prefixing `http://`.
    /// 3. `nil`.
    ///
    /// - Parameter raw: The raw decoded string, or `nil` when the field is absent/null.
    /// - Returns: `nil` for `nil`, empty, or unsalvageable input. Never throws.
    public static func parse(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // (a) Accept a clean single-token value that already reads as a real web URL.
        //     Values containing embedded commas/whitespace are dirty and routed to
        //     salvage instead of being accepted with the junk percent-encoded into the
        //     path (modern `URL(string:)` happily does that for a lone embedded space).
        if !containsSeparator(trimmed), let url = webURL(from: trimmed) {
            return url
        }

        // (b) Salvage the first usable token from a dirty value
        //     (e.g. "http://a.com, www.b.com" or "www.a.com and stuff").
        for token in trimmed.components(separatedBy: separators) where !token.isEmpty {
            if let url = webURL(from: token) {
                return url
            }
            if token.lowercased().hasPrefix("www."), let url = webURL(from: "http://" + token) {
                return url
            }
        }

        // (c) Nothing salvageable.
        return nil
    }

    /// Characters that separate distinct tokens in a dirty, multi-value field.
    private static let separators = CharacterSet(charactersIn: ",").union(.whitespacesAndNewlines)

    private static func containsSeparator(_ string: String) -> Bool {
        string.rangeOfCharacter(from: separators) != nil
    }

    /// A parsed value is usable only when it carries a scheme and a host, which filters
    /// out the scheme-less values modern `URL(string:)` happily produces from arbitrary
    /// text (spaces and other illegal characters get percent-encoded rather than rejected).
    private static func webURL(from string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme, !scheme.isEmpty,
              let host = url.host(percentEncoded: false), !host.isEmpty else {
            return nil
        }
        return url
    }
}

// MARK: - Decoding Helper

extension KeyedDecodingContainer {
    /// Decodes a user-entered URL field tolerantly (see ``LenientURL``).
    ///
    /// The value is decoded as a `String` and salvaged into a `URL`; an absent or null
    /// field stays `nil`, and a present-but-garbage string never throws. Use this in
    /// preference to `decodeIfPresent(URL.self, forKey:)` for any field that carries
    /// free-text supplied by API contributors.
    func decodeLenientURLIfPresent(forKey key: Key) throws -> URL? {
        let raw = try decodeIfPresent(String.self, forKey: key)
        return LenientURL.parse(raw)
    }
}
