import XCTest
@testable import PlayaAPI
import PlayaAPITestHelpers

/// Tests for tolerant decoding of user-entered URL fields.
///
/// Regression coverage for the empty-database import crash: a single junk `url`
/// value (e.g. Hel's Diner shipping `"http://www.campporta.org, www.helsdiner.com"`)
/// used to throw `DecodingError.dataCorrupted`, rolling back the entire single-transaction
/// import. User-entered URL fields must now salvage or resolve to `nil` instead of throwing.
final class LenientURLTests: XCTestCase {

    // MARK: - LenientURL.parse

    func testParse_HelsDinerString_SalvagesFirstURL() throws {
        // The exact junk value shipped in 2026 camp.json (uid a1XVI00000FHqT12AL, "Hel's Diner").
        let url = try XCTUnwrap(LenientURL.parse("http://www.campporta.org, www.helsdiner.com"))
        XCTAssertEqual(url, try XCTUnwrap(URL(string: "http://www.campporta.org")))
    }

    func testParse_WwwTokenWithTrailingJunk_PrefixesScheme() throws {
        let url = try XCTUnwrap(LenientURL.parse("www.example.com, other junk"))
        XCTAssertEqual(url, try XCTUnwrap(URL(string: "http://www.example.com")))
    }

    func testParse_WhitespaceSeparatedURLs_ReturnsFirst() throws {
        // Real mv.json value: two URLs separated by a space.
        let url = try XCTUnwrap(LenientURL.parse("https://www.instagram.com/foxartcar/ https://flic.kr/s/aHBqjCLmu2"))
        XCTAssertEqual(url, try XCTUnwrap(URL(string: "https://www.instagram.com/foxartcar/")))
    }

    func testParse_PureGarbage_ReturnsNil() {
        XCTAssertNil(LenientURL.parse("Come visit us at the corner!"))
    }

    func testParse_BareDomainWithoutSchemeOrWww_ReturnsNil() {
        // Documented salvage rule: only tokens with a scheme, or `www.*` tokens, are kept.
        // A bare "domain.org" is not salvaged (matches what a conservative sanitizer keeps).
        XCTAssertNil(LenientURL.parse("thegothicfolly.com"))
    }

    func testParse_EmptyAndWhitespaceStrings_ReturnNil() {
        XCTAssertNil(LenientURL.parse(""))
        XCTAssertNil(LenientURL.parse("   "))
    }

    func testParse_Nil_ReturnsNil() {
        XCTAssertNil(LenientURL.parse(nil))
    }

    func testParse_ValidURL_Unchanged() throws {
        let raw = "https://example.com/path?query=1"
        let url = try XCTUnwrap(LenientURL.parse(raw))
        XCTAssertEqual(url.absoluteString, raw)
    }

    // MARK: - Codable integration

    private func makeDecoder() -> JSONDecoder { PlayaAPI.createDecoder() }

    func testDecodeCamp_GarbageURL_Salvages() throws {
        let json = """
        { "uid": "a1XVI00000FHqT12AL", "name": "Hel's Diner", "year": 2026,
          "url": "http://www.campporta.org, www.helsdiner.com", "images": [] }
        """.data(using: .utf8)!
        let camp = try makeDecoder().decode(Camp.self, from: json)
        XCTAssertEqual(camp.url, try XCTUnwrap(URL(string: "http://www.campporta.org")))
    }

    func testDecodeCamp_AbsentURL_IsNil() throws {
        let json = """
        { "uid": "test", "name": "No URL Camp", "year": 2026, "images": [] }
        """.data(using: .utf8)!
        let camp = try makeDecoder().decode(Camp.self, from: json)
        XCTAssertNil(camp.url)
    }

    func testDecodeCamp_NullURL_IsNil() throws {
        let json = """
        { "uid": "test", "name": "Null URL Camp", "year": 2026, "url": null, "images": [] }
        """.data(using: .utf8)!
        let camp = try makeDecoder().decode(Camp.self, from: json)
        XCTAssertNil(camp.url)
    }

    func testDecodeCamp_UnsalvageableURL_IsNil() throws {
        let json = """
        { "uid": "test", "name": "Prose URL Camp", "year": 2026,
          "url": "Come visit us at the corner!", "images": [] }
        """.data(using: .utf8)!
        let camp = try makeDecoder().decode(Camp.self, from: json)
        XCTAssertNil(camp.url)
    }

    func testDecodeArt_GarbageDonationLink_Salvages() throws {
        // donationLink is user-entered too and must not throw.
        let json = """
        { "uid": "test", "name": "Art", "year": 2026,
          "donation_link": "www.donate.example.com and stuff",
          "images": [], "guided_tours": false, "self_guided_tour_map": false }
        """.data(using: .utf8)!
        let art = try makeDecoder().decode(Art.self, from: json)
        XCTAssertEqual(art.donationLink, try XCTUnwrap(URL(string: "http://www.donate.example.com")))
    }
}
