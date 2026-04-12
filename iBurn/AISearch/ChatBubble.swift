//
//  ChatBubble.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import SwiftUI
import PlayaDB

@available(iOS 26, *)
struct ChatBubble: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    let onNavigate: (String) -> Void
    @Environment(\.themeColors) var themeColors

    var body: some View {
        switch message.content {
        case .text(let text):
            textBubble(text, isUser: message.role == .user)

        case .objectCards(let cards):
            objectCardsView(cards)

        case .schedule(let schedule):
            scheduleView(schedule)

        case .adventure(let adventure):
            adventureView(adventure)

        case .quickActions(let actions):
            quickActionsView(actions)

        case .loading(let text):
            loadingView(text)

        case .error(let text):
            errorView(text)
        }
    }

    // MARK: - Text Bubble

    private func textBubble(_ text: String, isUser: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            Text(text)
                .font(.body)
                .foregroundColor(isUser ? .white : themeColors.primaryColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser ? themeColors.detailColor : Color(.systemGray6))
                )
            if !isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Object Cards

    private func objectCardsView(_ cards: [ObjectCard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(cards) { card in
                Button {
                    onNavigate(card.uid)
                } label: {
                    objectCardRow(card)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func objectCardRow(_ card: ObjectCard) -> some View {
        HStack(spacing: 10) {
            // Type badge
            Image(systemName: iconForType(card.type))
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(colorForType(card.type)))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(card.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeColors.primaryColor)
                        .lineLimit(1)

                    if viewModel.favoriteIDs.contains(card.uid) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(card.reason)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(2)
                }

                if let time = card.timeInfo {
                    Text(time)
                        .font(.caption2)
                        .foregroundColor(themeColors.detailColor)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }

    // MARK: - Schedule View

    private func scheduleView(_ schedule: ScheduleResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !schedule.summary.isEmpty {
                Text(schedule.summary)
                    .font(.subheadline)
                    .foregroundColor(themeColors.secondaryColor)
                    .padding(.bottom, 4)
            }

            if schedule.conflictsResolved > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(schedule.conflictsResolved) conflict\(schedule.conflictsResolved == 1 ? "" : "s") resolved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            ForEach(schedule.entries) { entry in
                Button { onNavigate(entry.uid) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let walk = entry.walkMinutesFromPrevious, walk > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.caption2)
                                Text("~\(walk) min walk")
                                    .font(.caption2)
                            }
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            VStack(spacing: 2) {
                                Text(entry.startTime)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeColors.detailColor)
                                Text(entry.endTime)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 60)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeColors.primaryColor)
                                    .lineLimit(1)
                                Text(entry.reason)
                                    .font(.caption)
                                    .foregroundColor(themeColors.secondaryColor)
                                    .lineLimit(2)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Adventure View

    private func adventureView(_ adventure: AdventureResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(adventure.narrative)
                .font(.subheadline)
                .foregroundColor(themeColors.primaryColor)

            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                Text("Total: ~\(adventure.totalWalkMinutes) min walking")
                    .font(.caption)
            }
            .foregroundColor(themeColors.secondaryColor)

            ForEach(Array(adventure.stops.enumerated()), id: \.element.id) { index, stop in
                Button { onNavigate(stop.uid) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let walk = stop.walkMinutesFromPrevious, walk > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.walk")
                                    .font(.caption2)
                                Text("~\(walk) min walk")
                                    .font(.caption2)
                            }
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        }

                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(themeColors.detailColor))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(stop.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(themeColors.primaryColor)
                                        .lineLimit(1)
                                    Image(systemName: iconForType(stop.type))
                                        .font(.caption2)
                                        .foregroundColor(colorForType(stop.type))
                                }
                                Text(stop.tip)
                                    .font(.caption)
                                    .foregroundColor(themeColors.secondaryColor)
                                    .lineLimit(2)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick Actions

    private func quickActionsView(_ actions: [QuickAction]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Button {
                        viewModel.inputText = action.prompt
                        viewModel.send()
                    } label: {
                        Text(action.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(themeColors.detailColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .stroke(themeColors.detailColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Loading

    private func loadingView(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(text)
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Error

    private func errorView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Helpers

    private func iconForType(_ type: DataObjectType) -> String {
        switch type {
        case .art: return "paintpalette"
        case .camp: return "tent"
        case .event: return "calendar"
        case .mutantVehicle: return "car"
        }
    }

    private func colorForType(_ type: DataObjectType) -> Color {
        switch type {
        case .art: return .purple
        case .camp: return .orange
        case .event: return .blue
        case .mutantVehicle: return .green
        }
    }
}

#endif
