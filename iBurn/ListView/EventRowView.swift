import SwiftUI
import PlayaDB
import UIKit

/// Row view for an event occurrence in the event list.
/// Layout matches the old UIKit `BRCEventObjectTableViewCell` XIB:
///   Row 1: [Heart] [Title] [Type Emoji]
///   Row 2: [Host Name] ... [Playa Address]
///   Row 3: [Camp Thumbnail 75×75] [Description]
///   Row 4: [Distance] ... [Time/Status]
struct EventRowView: View {
    let event: EventObjectOccurrence
    let hostName: String?
    let hostAddress: String?
    let hostDescription: String?
    let campUID: String?
    let isArtHosted: Bool
    let distanceString: AttributedString?
    let isFavorite: Bool
    let now: Date
    let onFavoriteTap: () -> Void

    @StateObject private var assets: RowAssetsLoader
    @Environment(\.themeColors) var themeColors

    private let thumbnailSize: CGFloat = 75

    init(
        event: EventObjectOccurrence,
        hostName: String?,
        hostAddress: String?,
        hostDescription: String?,
        campUID: String?,
        isArtHosted: Bool,
        distanceString: AttributedString?,
        isFavorite: Bool,
        now: Date,
        onFavoriteTap: @escaping () -> Void
    ) {
        self.event = event
        self.hostName = hostName
        self.hostAddress = hostAddress
        self.hostDescription = hostDescription
        self.campUID = campUID
        self.isArtHosted = isArtHosted
        self.distanceString = distanceString
        self.isFavorite = isFavorite
        self.now = now
        self.onFavoriteTap = onFavoriteTap
        _assets = StateObject(wrappedValue: RowAssetsLoader(objectID: campUID ?? ""))
    }

    private var hasThumbnail: Bool {
        campUID != nil && assets.thumbnail != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: [Heart] [Title] [Type Emoji]
            HStack(spacing: 4) {
                Button(action: onFavoriteTap) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .pink : themeColors.detailColor)
                }
                .buttonStyle(.plain)
                .frame(width: 25, height: 25)

                Text(event.name)
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(EventTypeInfo.emoji(for: event.eventTypeCode))
                    .font(.subheadline)
                    .frame(width: 25, alignment: .trailing)
            }

            // Row 2: [Host Name] ... [Location Address]
            if hostName != nil || hostAddress != nil {
                HStack(spacing: 8) {
                    if let hostName {
                        Text(isArtHosted ? "🎨 \(hostName)" : hostName)
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if let hostAddress {
                        Text(hostAddress)
                            .font(.subheadline)
                            .foregroundColor(themeColors.detailColor)
                            .lineLimit(1)
                    }
                }
            }

            // Row 3: [Thumbnail 75×75] [Description]
            HStack(alignment: .top, spacing: 8) {
                if hasThumbnail, let thumbnail = assets.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text(combinedDescription)
                    .font(.caption)
                    .foregroundColor(themeColors.detailColor)
                    .lineLimit(nil)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: thumbnailSize, alignment: .top)

            // Row 4: [Distance] ... [Time/Status]
            HStack {
                if let distanceString {
                    Text(distanceString)
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text("🚶🏽 ? min   🚴🏽 ? min")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                statusView
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Combined Description

    private var combinedDescription: String {
        let parts = [event.description, hostDescription].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.joined(separator: "\n")
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        Text(statusText)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .lineLimit(1)
    }

    private var statusText: String {
        if event.allDay {
            return "\(dayAbbrev(event.startDate)) (All Day)"
        }
        if event.isStartingSoon(now) {
            let durationStr = DateFormatters.stringForTimeInterval(event.duration) ?? "0m"
            let startInterval = event.timeIntervalUntilStart(now)
            let startStr = DateFormatters.stringForTimeInterval(startInterval) ?? "now!"
            if startStr.isEmpty || startInterval <= 0 {
                return "Starts now! (\(durationStr))"
            }
            return "Starts \(startStr) (\(durationStr))"
        }
        if event.isCurrentlyHappening(now) {
            let endInterval = event.timeIntervalUntilEnd(now)
            let endStr = DateFormatters.stringForTimeInterval(endInterval) ?? "0m"
            let startTime = timeString(event.startDate)
            return "\(startTime) (\(endStr) left)"
        }
        return defaultEventText
    }

    private var defaultEventText: String {
        let startTime = timeString(event.startDate)
        let durationStr = DateFormatters.stringForTimeInterval(event.duration) ?? "0m"
        let day = dayAbbrev(event.startDate)
        // Lowercase only the time+duration portion, keep day abbreviation capitalized
        let timePart = "\(startTime) (\(durationStr))".lowercased()
        return "\(day) \(timePart)"
    }

    private var statusColor: Color {
        if event.allDay { return .secondary }
        if event.isCurrentlyHappening(now) { return .green }
        if event.isStartingSoon(now) { return .orange }
        if event.hasEnded(now) { return .secondary }
        return themeColors.secondaryColor
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }

    private func dayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

}
