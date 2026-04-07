//
//  IntentClassifier.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels

// MARK: - Intent Types

@available(iOS 26, *)
enum ChatIntent: Sendable {
    case search(query: String)
    case recommend
    case dayPlan
    case nearby
    case adventure(theme: String?)
    case scheduleOptimize
    case serendipity
    case campCrawl(theme: String?)
    case whatDidIMiss
    case goldenHour
    case general(query: String)
}

// MARK: - Generable Intent

@available(iOS 26, *)
@Generable
struct ClassifiedIntent {
    @Guide(description: "One of: search, recommend, dayPlan, nearby, adventure, scheduleOptimize, serendipity, campCrawl, whatDidIMiss, goldenHour, general")
    var intent: String
    @Guide(description: "Extracted theme, query, or search terms if applicable")
    var parameter: String?
}

// MARK: - Intent Classifier

@available(iOS 26, *)
struct IntentClassifier {

    private static let instructions = """
        You classify user messages for a Burning Man festival guide app. \
        Determine the user's intent from: \
        search (looking for specific things), \
        recommend (want personalized suggestions), \
        dayPlan (want a day schedule), \
        nearby (what's around me), \
        adventure (want a themed playa tour/adventure), \
        scheduleOptimize (fix schedule conflicts for favorited events), \
        serendipity (surprise me / random discovery), \
        campCrawl (camp-hopping route, e.g. coffee trail, music camps), \
        whatDidIMiss (things I walked past but didn't visit), \
        goldenHour (sunrise/sunset art viewing), \
        general (other questions). \
        Extract the theme or query if present.
        """

    static func classify(_ message: String) async throws -> ChatIntent {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: Prompt(message),
            generating: ClassifiedIntent.self
        )
        return mapIntent(response.content)
    }

    private static func mapIntent(_ classified: ClassifiedIntent) -> ChatIntent {
        let param = classified.parameter?.nilIfEmpty
        switch classified.intent.lowercased() {
        case "search":
            return .search(query: param ?? "")
        case "recommend":
            return .recommend
        case "dayplan":
            return .dayPlan
        case "nearby":
            return .nearby
        case "adventure":
            return .adventure(theme: param)
        case "scheduleoptimize":
            return .scheduleOptimize
        case "serendipity":
            return .serendipity
        case "campcrawl":
            return .campCrawl(theme: param)
        case "whatdidimiss":
            return .whatDidIMiss
        case "goldenhour":
            return .goldenHour
        default:
            return .general(query: param ?? classified.intent)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

#endif
