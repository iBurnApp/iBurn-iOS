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
                ForEach(configuration.visible, id: \.self) { identifier in
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
                    ForEach(configuration.hidden, id: \.self) { identifier in
                        row(identifier, isHidden: true)
                    }
                }
            } header: {
                Text("In More")
            } footer: {
                Text("Hidden tabs stay reachable as rows at the top of the More screen.")
                    .font(.footnote)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    apply(.default)
                }
                .disabled(configuration == .default)
            }
        }
    }

    private func row(_ identifier: TabIdentifier, isHidden: Bool) -> some View {
        HStack(spacing: 12) {
            if identifier.isHideable {
                Button {
                    isHidden ? show(identifier) : hide(identifier)
                } label: {
                    Image(systemName: isHidden ? "plus.circle.fill" : "minus.circle.fill")
                        .foregroundColor(isHidden ? .green : .red)
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
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

struct CustomizeTabsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CustomizeTabsView()
        }
    }
}
