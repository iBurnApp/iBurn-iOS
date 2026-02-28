import SwiftUI
import PlayaDB

/// Row view for an event occurrence in the event list.
struct EventRowView: View {
    let event: EventObjectOccurrence
    let locationString: String?
    let distanceString: AttributedString?
    let isFavorite: Bool
    let now: Date
    let onFavoriteTap: () -> Void
    @Environment(\.themeColors) var themeColors

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Event type emoji
            Text(EventTypeInfo.emoji(for: event.eventTypeCode))
                .font(.title2)
                .frame(width: 32, alignment: .center)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(themeColors.primaryColor)

                if let locationString {
                    Text(locationString)
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(1)
                }

                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(themeColors.detailColor)
                        .lineLimit(2)
                }

                HStack {
                    statusView
                    Spacer()
                    if let distanceString {
                        Text(distanceString)
                            .font(.caption)
                    }
                }
            }

            // Favorite button
            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .pink : themeColors.detailColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
    }

    private var statusText: String {
        if event.allDay {
            return "All Day"
        }
        if event.isCurrentlyHappening(now) {
            let minutesLeft = Int(event.timeIntervalUntilEnd(now) / 60)
            if minutesLeft > 60 {
                let hours = minutesLeft / 60
                let mins = minutesLeft % 60
                return mins > 0 ? "Now · \(hours)h \(mins)m left" : "Now · \(hours)h left"
            }
            return "Now · \(minutesLeft)m left"
        }
        if event.isStartingSoon(now) {
            let minutesUntil = Int(event.timeIntervalUntilStart(now) / 60)
            return "Starts in \(minutesUntil)m"
        }
        if event.hasEnded(now) {
            return "\(timeString(event.startDate)) (\(event.durationString))"
        }
        return "\(timeString(event.startDate)) (\(event.durationString))"
    }

    private var statusColor: Color {
        if event.allDay { return .secondary }
        if event.isCurrentlyHappening(now) { return .green }
        if event.isStartingSoon(now) { return .orange }
        if event.hasEnded(now) { return .secondary }
        return themeColors.detailColor
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: date)
    }
}
