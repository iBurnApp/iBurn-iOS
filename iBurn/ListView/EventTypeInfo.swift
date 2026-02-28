import Foundation

/// Pure Swift mapping of event type codes to display names and emoji.
///
/// Decouples SwiftUI event views from the legacy ObjC `BRCEventType` enum.
/// Codes verified against 2025 bundled API data.
struct EventTypeInfo: Identifiable {
    let code: String
    let displayName: String
    let emoji: String

    var id: String { code }

    /// Event types that have data in the current dataset.
    static let visibleTypes: [EventTypeInfo] = [
        EventTypeInfo(code: "work", displayName: "Class/Workshop", emoji: "🧑‍🏫"),
        EventTypeInfo(code: "prty", displayName: "Music/Party", emoji: "🎉"),
        EventTypeInfo(code: "food", displayName: "Food", emoji: "🍔"),
        EventTypeInfo(code: "arts", displayName: "Arts & Crafts", emoji: "🎨"),
        EventTypeInfo(code: "tea",  displayName: "Beverages", emoji: "🍹"),
        EventTypeInfo(code: "adlt", displayName: "Mature Audiences", emoji: "🔞"),
        EventTypeInfo(code: "kid",  displayName: "Kids Activities", emoji: "👨‍👩‍👧‍👦"),
        EventTypeInfo(code: "othr", displayName: "Other", emoji: "🤷"),
    ]

    /// All known codes (including historical types no longer in active use).
    private static let allTypes: [String: EventTypeInfo] = {
        let types: [EventTypeInfo] = visibleTypes + [
            EventTypeInfo(code: "perf", displayName: "Performance", emoji: "💃"),
            EventTypeInfo(code: "sprt", displayName: "Self Care", emoji: "🏥"),
            EventTypeInfo(code: "cere", displayName: "Ritual/Ceremony", emoji: "🔮"),
            EventTypeInfo(code: "game", displayName: "Games", emoji: "🎯"),
            EventTypeInfo(code: "fire", displayName: "Fire/Spectacle", emoji: "🔥"),
            EventTypeInfo(code: "prde", displayName: "Parade", emoji: "🎏"),
            EventTypeInfo(code: "hlng", displayName: "Healing/Massage/Spa", emoji: "💆"),
            EventTypeInfo(code: "lgbt", displayName: "LGBTQIA2S+", emoji: "🌈"),
            EventTypeInfo(code: "live", displayName: "Live Music", emoji: "🎺"),
            EventTypeInfo(code: "ride", displayName: "Diversity & Inclusion", emoji: "💗"),
            EventTypeInfo(code: "repr", displayName: "Repair", emoji: "🔨"),
            EventTypeInfo(code: "sust", displayName: "Sustainability", emoji: "♻️"),
            EventTypeInfo(code: "medt", displayName: "Yoga/Movement/Fitness", emoji: "🧘"),
        ]
        return Dictionary(uniqueKeysWithValues: types.map { ($0.code, $0) })
    }()

    static func emoji(for code: String) -> String {
        allTypes[code]?.emoji ?? "🤷"
    }

    static func displayName(for code: String) -> String {
        allTypes[code]?.displayName ?? code
    }
}
