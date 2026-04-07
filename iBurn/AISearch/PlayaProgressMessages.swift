//
//  PlayaProgressMessages.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// Whimsical, playa-themed progress messages for AI workflow steps.
/// Each step type has a pool of messages; one is picked at random.
enum PlayaProgressMessages {

    // MARK: - Understanding Taste

    static let tasteProfiling = [
        "Reading your vibe from favorites...",
        "Channeling your inner burner...",
        "Consulting the playa oracle about your taste...",
        "Analyzing your art appreciation wavelength...",
        "Decoding your festival frequency...",
    ]

    // MARK: - Searching / Exploring

    static let searching = [
        "Sending scouts across the playa...",
        "Asking the dust bunnies for tips...",
        "Decoding the What Where When guide...",
        "Scanning the horizon for hidden gems...",
        "Following the sound of distant bass...",
    ]

    static let searchingArt = [
        "Wandering through the art fields...",
        "Squinting at the deep playa mirages...",
        "Following the glow of neon in the dust...",
        "Asking the Man which way to go...",
    ]

    static let searchingCamps = [
        "Peeking behind theme camp curtains...",
        "Following the smell of fresh pancakes...",
        "Checking which camps have their flags up...",
        "Knocking on geodesic domes...",
    ]

    static let searchingEvents = [
        "Flipping through the event guide by flashlight...",
        "Checking who's throwing a party tonight...",
        "Asking a stranger on a megaphone...",
        "Tuning into the playa grapevine...",
    ]

    // MARK: - Curating / Selecting

    static let curating = [
        "Separating the sparkle from the dust...",
        "Curating your personal playa gallery...",
        "Picking the juiciest experiences...",
        "Applying radical inclusion to your options...",
        "Gifting you the best of the playa...",
    ]

    // MARK: - Route Planning

    static let routing = [
        "Calculating dust-to-dust walking times...",
        "Plotting a course through the grid...",
        "Optimizing your bike route past porta-potties...",
        "Factoring in deep playa sand resistance...",
        "Charting a course by the stars (and street signs)...",
    ]

    // MARK: - Schedule Optimization

    static let conflictDetection = [
        "Looking for schedule pile-ups...",
        "Checking for space-time conflicts...",
        "Making sure you can't be in two places at once...",
        "Untangling your overlapping desires...",
    ]

    static let conflictResolution = [
        "Making the tough calls so you don't have to...",
        "Applying playa wisdom to scheduling conflicts...",
        "Choosing between two equally awesome things...",
        "Consulting the Temple of Hard Decisions...",
    ]

    // MARK: - Narrative / Writing

    static let writing = [
        "Crafting your playa story...",
        "Channeling the spirit of the burn...",
        "Writing with dust-stained fingers...",
        "Composing your desert symphony...",
        "Weaving tales of radical self-reliance...",
    ]

    // MARK: - Serendipity

    static let serendipity = [
        "Rolling the cosmic dice...",
        "Embracing radical spontaneity...",
        "Shaking the magic 8-ball of the playa...",
        "Consulting the chaos butterfly...",
        "Letting the dust decide your fate...",
    ]

    static let creativeConnections = [
        "Finding the invisible threads between things...",
        "Making connections only the playa could...",
        "Discovering why the universe put these together...",
        "Unearthing the hidden harmony...",
    ]

    // MARK: - Location History

    static let analyzingTracks = [
        "Retracing your dusty footsteps...",
        "Following your breadcrumb trail through the desert...",
        "Reading the story your feet wrote in the playa...",
        "Analyzing your wander pattern...",
    ]

    static let findingMissed = [
        "Spotting the treasures you walked right past...",
        "Discovering what was hiding in plain sight...",
        "Finding the gems you didn't know you missed...",
        "Checking what was just around the corner...",
    ]

    // MARK: - Golden Hour

    static let goldenHour = [
        "Calculating the angle of desert magic...",
        "Finding art that glows at golden hour...",
        "Scouting silhouettes against the sunset...",
        "Mapping where the light hits just right...",
    ]

    // MARK: - Camp Crawl

    static let campEvents = [
        "Checking what's on the menu at each camp...",
        "Peeking at camp event boards...",
        "Asking camp leads what's popping...",
        "Scouting the vibes at each stop...",
    ]

    // MARK: - General

    static let thinking = [
        "Putting on the thinking goggles...",
        "Consulting the desert wisdom database...",
        "Processing through the dust filter...",
        "Meditating on your question at the Temple...",
    ]

    static let finishing = [
        "Dusting off the final results...",
        "Putting a bow on your playa package...",
        "Ready to blow your mind...",
        "Polishing the crystal ball...",
    ]

    // MARK: - Helper

    static func random(from pool: [String]) -> String {
        pool.randomElement() ?? "Working on it..."
    }
}
