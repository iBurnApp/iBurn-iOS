//
//  ReviewPromptPolicy.swift
//  iBurn
//
//  Decides when to ask StoreKit for an App Store review. Replaces Appirater, whose
//  configuration this keeps: at least 2 days and 5 launches since the current version was
//  first run. StoreKit shows its own system prompt (no custom pre-alert) and rate-limits it
//  to 3 times a year, so on top of that this asks at most once per app version.
//

import Foundation
import StoreKit
import UIKit

/// When the app may ask for a review. State lives in `UserDefaults`.
protocol ReviewPromptPolicy: AnyObject {
    /// Counts one use of the app (a launch). A new app version restarts the count and the
    /// day clock, as Appirater did.
    func recordUse(now: Date)

    /// Whether enough days and uses have passed and this version hasn't asked yet.
    func shouldRequestReview(now: Date) -> Bool

    /// Notes that a review was requested for the current version.
    func recordReviewRequested(now: Date)
}

struct ReviewPromptConfiguration: Equatable {
    /// Days since this version's first use before asking (Appirater `daysUntilPrompt`).
    var daysUntilPrompt: Int = 2
    /// Launches of this version before asking (Appirater `usesUntilPrompt`).
    var usesUntilPrompt: Int = 5
}

final class ReviewPromptPolicyImpl: ReviewPromptPolicy {

    enum Keys {
        static let trackingVersion = "ReviewPrompt.trackingVersion"
        static let firstUseDate = "ReviewPrompt.firstUseDate"
        static let useCount = "ReviewPrompt.useCount"
        static let requestedVersion = "ReviewPrompt.requestedVersion"
        static let lastRequestDate = "ReviewPrompt.lastRequestDate"
    }

    private let defaults: UserDefaults
    private let appVersion: String
    private let configuration: ReviewPromptConfiguration

    init(
        defaults: UserDefaults,
        appVersion: String,
        configuration: ReviewPromptConfiguration = ReviewPromptConfiguration()
    ) {
        self.defaults = defaults
        self.appVersion = appVersion
        self.configuration = configuration
    }

    func recordUse(now: Date) {
        if defaults.string(forKey: Keys.trackingVersion) != appVersion {
            defaults.set(appVersion, forKey: Keys.trackingVersion)
            defaults.set(now, forKey: Keys.firstUseDate)
            defaults.set(1, forKey: Keys.useCount)
            return
        }
        if defaults.object(forKey: Keys.firstUseDate) == nil {
            defaults.set(now, forKey: Keys.firstUseDate)
        }
        defaults.set(defaults.integer(forKey: Keys.useCount) + 1, forKey: Keys.useCount)
    }

    func shouldRequestReview(now: Date) -> Bool {
        guard defaults.string(forKey: Keys.trackingVersion) == appVersion,
              defaults.string(forKey: Keys.requestedVersion) != appVersion,
              let firstUse = defaults.object(forKey: Keys.firstUseDate) as? Date else {
            return false
        }
        guard defaults.integer(forKey: Keys.useCount) >= configuration.usesUntilPrompt else {
            return false
        }
        let requiredInterval = TimeInterval(configuration.daysUntilPrompt) * 24 * 60 * 60
        return now.timeIntervalSince(firstUse) >= requiredInterval
    }

    func recordReviewRequested(now: Date) {
        defaults.set(appVersion, forKey: Keys.requestedVersion)
        defaults.set(now, forKey: Keys.lastRequestDate)
    }
}

/// Shows the system review prompt. Wraps StoreKit so the scene glue can be exercised
/// without it.
protocol ReviewRequesting {
    @MainActor func requestReview(in windowScene: UIWindowScene)
}

struct StoreKitReviewRequester: ReviewRequesting {
    @MainActor func requestReview(in windowScene: UIWindowScene) {
        AppStore.requestReview(in: windowScene)
    }
}

/// Builds the app's review policy and requester, hiding the implementations.
enum ReviewPromptFactory {
    static func makePolicy(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) -> ReviewPromptPolicy {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return ReviewPromptPolicyImpl(defaults: defaults, appVersion: version)
    }

    static func makeRequester() -> ReviewRequesting {
        StoreKitReviewRequester()
    }
}
