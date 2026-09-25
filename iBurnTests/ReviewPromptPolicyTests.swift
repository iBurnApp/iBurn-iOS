//
//  ReviewPromptPolicyTests.swift
//  iBurnTests
//
//  The StoreKit review prompt replaced Appirater. These pin the thresholds Appirater was
//  configured with (2 days, 5 launches) and the once-per-version rule.
//

import XCTest
@testable import iBurn

final class ReviewPromptPolicyTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_780_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    /// A throwaway defaults domain, set up fresh for every test.
    private var defaults = UserDefaults()

    override func setUpWithError() throws {
        let suiteName = "ReviewPromptPolicyTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { [defaults] in
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func makePolicy(version: String = "2026.1") -> ReviewPromptPolicy {
        ReviewPromptPolicyImpl(defaults: defaults, appVersion: version)
    }

    private func recordUses(_ count: Int, on policy: ReviewPromptPolicy, at date: Date) {
        for _ in 0..<count {
            policy.recordUse(now: date)
        }
    }

    func testDefaultConfigurationMatchesAppirater() {
        let configuration = ReviewPromptConfiguration()
        XCTAssertEqual(configuration.daysUntilPrompt, 2)
        XCTAssertEqual(configuration.usesUntilPrompt, 5)
    }

    func testFreshInstallDoesNotPrompt() {
        let policy = makePolicy()
        XCTAssertFalse(policy.shouldRequestReview(now: start))
        XCTAssertFalse(policy.shouldRequestReview(now: start + 30 * day))
    }

    func testEnoughUsesButTooSoonDoesNotPrompt() {
        let policy = makePolicy()
        recordUses(5, on: policy, at: start)
        XCTAssertFalse(policy.shouldRequestReview(now: start + 2 * day - 1))
    }

    func testEnoughDaysButTooFewUsesDoesNotPrompt() {
        let policy = makePolicy()
        recordUses(4, on: policy, at: start)
        XCTAssertFalse(policy.shouldRequestReview(now: start + 10 * day))
    }

    func testFiveUsesAfterTwoDaysPrompts() {
        let policy = makePolicy()
        recordUses(5, on: policy, at: start)
        XCTAssertTrue(policy.shouldRequestReview(now: start + 2 * day))
    }

    func testDaysCountFromFirstUseNotLatest() {
        let policy = makePolicy()
        policy.recordUse(now: start)
        recordUses(4, on: policy, at: start + 2 * day)
        XCTAssertTrue(policy.shouldRequestReview(now: start + 2 * day))
    }

    func testOnlyAsksOncePerVersion() {
        let policy = makePolicy()
        recordUses(5, on: policy, at: start)
        XCTAssertTrue(policy.shouldRequestReview(now: start + 3 * day))
        policy.recordReviewRequested(now: start + 3 * day)
        recordUses(20, on: policy, at: start + 4 * day)
        XCTAssertFalse(policy.shouldRequestReview(now: start + 60 * day))
    }

    func testNewVersionRestartsTracking() {
        let old = makePolicy(version: "2026.1")
        recordUses(5, on: old, at: start)
        old.recordReviewRequested(now: start + 3 * day)

        let updated = makePolicy(version: "2026.2")
        let updateDay = start + 10 * day
        updated.recordUse(now: updateDay)
        XCTAssertFalse(updated.shouldRequestReview(now: updateDay + 5 * day), "one use of the new version")

        recordUses(4, on: updated, at: updateDay + day)
        XCTAssertFalse(updated.shouldRequestReview(now: updateDay + 2 * day - 1), "day clock restarted")
        XCTAssertTrue(updated.shouldRequestReview(now: updateDay + 2 * day))
    }

    func testStatePersistsAcrossInstances() {
        recordUses(3, on: makePolicy(), at: start)
        recordUses(2, on: makePolicy(), at: start + day)
        XCTAssertTrue(makePolicy().shouldRequestReview(now: start + 2 * day))
    }

    func testCustomConfiguration() {
        let policy = ReviewPromptPolicyImpl(
            defaults: defaults,
            appVersion: "1",
            configuration: ReviewPromptConfiguration(daysUntilPrompt: 0, usesUntilPrompt: 1)
        )
        policy.recordUse(now: start)
        XCTAssertTrue(policy.shouldRequestReview(now: start))
    }
}
