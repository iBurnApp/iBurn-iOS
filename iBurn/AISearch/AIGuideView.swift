//
//  AIGuideView.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import SwiftUI
import PlayaDB
import UIKit

@available(iOS 26, *)
struct AIGuideView: View {
    @ObservedObject var viewModel: AIGuideViewModel
    @Environment(\.themeColors) var themeColors

    var body: some View {
        List {
            ForEach(WorkflowSection.allCases, id: \.rawValue) { section in
                let workflows = WorkflowCatalog.workflows(for: section)
                if !workflows.isEmpty {
                    Section(header: Text(section.rawValue)) {
                        ForEach(workflows) { workflow in
                            NavigationLink {
                                WorkflowDetailView(
                                    workflowInfo: workflow,
                                    viewModel: viewModel
                                )
                            } label: {
                                WorkflowRow(info: workflow, themeColors: themeColors)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI Guide")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Workflow Row

@available(iOS 26, *)
struct WorkflowRow: View {
    let info: WorkflowInfo
    let themeColors: ImageColors

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: info.icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForWorkflow(info.id))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.primaryColor)
                Text(info.subtitle)
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryColor)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForWorkflow(_ id: WorkflowID) -> Color {
        switch id {
        case .forYou: return .purple
        case .surpriseMe: return .orange
        case .whatDidIMiss: return .indigo
        case .dayPlanner: return .blue
        case .adventure: return .green
        case .campCrawl: return .pink
        case .goldenHour: return .yellow
        case .scheduleOptimizer: return .teal
        }
    }
}

#endif
