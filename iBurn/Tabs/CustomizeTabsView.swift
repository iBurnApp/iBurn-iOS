//
//  CustomizeTabsView.swift
//  iBurn
//
//  Created by Claude Code on 8/8/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI

/// Lets the user reorder the tab bar and move tabs into the More list. Edits write
/// straight through to `TabConfiguration.current`, which rebuilds the bar underneath
/// this screen — there is nothing to save and nothing to cancel.
struct CustomizeTabsView: View {

    @State private var configuration = TabConfiguration.current

    var body: some View {
        List {
            Section {
                ForEach(configuration.visible, id: \.barRowID) { identifier in
                    row(identifier, isHidden: false)
                }
                .onMove(perform: move)
            } header: {
                Text("Tab Bar")
            } footer: {
                Text("Drag to reorder. Map and More always stay on the tab bar.")
                    .font(.footnote)
            }

            Section {
                if configuration.hidden.isEmpty {
                    Text("Nothing hidden.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(configuration.hidden, id: \.moreRowID) { identifier in
                        row(identifier, isHidden: true)
                    }
                }
            } header: {
                Text("In More")
            } footer: {
                Text(hiddenFooter)
                    .font(.footnote)
            }
        }
        // The list is permanently in edit mode, and a cell recycled across the section
        // boundary keeps the wrong edit chrome: a just-unhidden row arrived with no
        // reorder handle and the next drag crashed. Re-identifying the list whenever the
        // visible/hidden partition changes configures every cell fresh; reorders leave
        // `hidden` untouched, so a drag never rebuilds mid-gesture.
        .id(configuration.hidden)
        .environment(\.editMode, .constant(.active))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    TabConfiguration.resetToDefault()
                    withAnimation { configuration = TabConfiguration.current }
                }
                .disabled(TabConfiguration.isUntouched)
            }
        }
    }

    /// No slot left for another tab. Un-hiding past capacity would push the bar to six
    /// items and summon UIKit's native More overflow, so the plus buttons shut off.
    private var isAtCapacity: Bool {
        configuration.visible.count >= TabConfiguration.visibleCapacity
    }

    /// Says why Events starts down here when the search tab owns a bar slot — otherwise
    /// it looks like the app hid a tab for no reason — and why plus is greyed out when
    /// the bar is full.
    private var hiddenFooter: String {
        var text = "Hidden tabs stay reachable as rows at the top of the More screen."
        let eventsDisplacedBySearch = TabConfiguration.layoutHiddenByDefault.contains(.events)
            && configuration.isHidden(.events)
        if eventsDisplacedBySearch {
            text += " Events starts here because the search tab takes a slot on the bar."
        }
        if isAtCapacity && !configuration.hidden.isEmpty {
            // Mention the search tab only when it's the reason and the Events sentence
            // hasn't already said so.
            text += eventsDisplacedBySearch || !TabConfiguration.searchTabOccupiesBarSlot
                ? " The tab bar is full — hide another tab to add one back."
                : " The tab bar is full — the search tab holds one slot, so hide another tab to add one back."
        }
        return text
    }

    private func row(_ identifier: TabIdentifier, isHidden: Bool) -> some View {
        let addBlocked = isHidden && isAtCapacity
        return HStack(spacing: 12) {
            if identifier.isHideable {
                Button {
                    isHidden ? show(identifier) : hide(identifier)
                } label: {
                    Image(systemName: isHidden ? "plus.circle.fill" : "minus.circle.fill")
                        .foregroundColor(addBlocked ? .secondary : isHidden ? .green : .red)
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .disabled(addBlocked)
                .accessibilityLabel(isHidden ? "Add \(identifier.title) to tab bar" : "Remove \(identifier.title) from tab bar")
            } else {
                // Keeps titles aligned with the hideable rows above and below.
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
                    .accessibilityLabel("\(identifier.title) can't be hidden")
            }

            Image(identifier.imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.primary)

            Text(identifier.title)
        }
    }

    // MARK: - Editing

    private func move(from source: IndexSet, to destination: Int) {
        var visible = configuration.visible
        visible.move(fromOffsets: source, toOffset: destination)
        apply(TabConfiguration(visible: visible, hidden: configuration.hidden))
    }

    private func hide(_ identifier: TabIdentifier) {
        guard identifier.isHideable else { return }
        apply(TabConfiguration(
            visible: configuration.visible.filter { $0 != identifier },
            hidden: configuration.hidden + [identifier]
        ))
    }

    private func show(_ identifier: TabIdentifier) {
        guard !isAtCapacity else { return }
        apply(TabConfiguration(
            visible: configuration.visible + [identifier],
            hidden: configuration.hidden.filter { $0 != identifier }
        ))
    }

    /// Persisting sanitizes, so read the stored value back rather than trusting the edit.
    private func apply(_ newValue: TabConfiguration) {
        TabConfiguration.current = newValue
        withAnimation {
            configuration = TabConfiguration.current
        }
    }
}

/// Row identity carries its section. Both ForEach containers hold `TabIdentifier`
/// values, and one identity migrating between them mid-edit made the List recycle the
/// cell — stale edit chrome (no reorder handle) and corrupted move bookkeeping.
/// Distinct namespaces turn a show/hide into a plain delete + insert.
private extension TabIdentifier {
    var barRowID: String { "bar." + rawValue }
    var moreRowID: String { "more." + rawValue }
}

struct CustomizeTabsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CustomizeTabsView()
        }
    }
}
