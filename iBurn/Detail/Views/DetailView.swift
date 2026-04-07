//
//  DetailView.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

// MARK: - Theme Colors Environment

struct ThemeColorsEnvironmentKey: EnvironmentKey {
    static let defaultValue: ImageColors = ImageColors(Appearance.currentColors)
}

extension EnvironmentValues {
    var themeColors: ImageColors {
        get { self[ThemeColorsEnvironmentKey.self] }
        set { self[ThemeColorsEnvironmentKey.self] = newValue }
    }
}

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeColors) var themeColors
    
    init(viewModel: DetailViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    private var backgroundColor: Color {
        return viewModel.getThemeColors().backgroundColor
    }
    
    private var imageViewerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedImage != nil },
            set: { if !$0 { viewModel.selectedImage = nil } }
        )
    }
    
    var body: some View {
        ScrollView {
            // Content sections
            VStack(spacing: 8) {
                ForEach(viewModel.cells) { cell in
                    DetailCellView(cell: cell, viewModel: viewModel)
                }
            }
            .padding(.bottom, 8)
        }
        .environment(\.themeColors, viewModel.getThemeColors())
        .background(backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(viewModel.title)
        .sheet(isPresented: imageViewerBinding) {
            if let selected = viewModel.selectedImage {
                ImageViewerSheet(image: selected)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share button
                Button(action: {
                    viewModel.shareObject()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .accessibilityLabel("Share")
                        .font(.body)
                }
                
                // Add to Calendar button for events
                if viewModel.showsCalendarButton {
                    Button(action: {
                        viewModel.showEventEditor()
                    }) {
                        Image(systemName: "calendar.badge.plus")
                            .accessibilityLabel("Add to Calendar")
                            .font(.body)
                    }
                }
                
                // Favorite button for all object types
                Button(action: {
                    Task { await viewModel.toggleFavorite() }
                }) {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .font(.body)
                        .accessibilityLabel(viewModel.isFavorite ?  "Remove Favorite" : "Add Favorite")
                        .foregroundColor(viewModel.isFavorite ? .pink : themeColors.detailColor)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}


// MARK: - Supporting Views

struct DetailImageView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipped()
    }
}

struct DetailCellView: View {
    let cell: DetailCell
    let viewModel: DetailViewModel
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isCellTappable(cell.type) {
                Button(action: {
                    viewModel.handleCellTap(cell)
                }) {
                    cellContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            } else {
                cellContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, shouldAddVerticalPadding ? 16 : 0)
        .padding(.horizontal, shouldAddHorizontalPadding ? 16 : 0)
    }
    
    private var shouldAddHorizontalPadding: Bool {
        switch cell.type {
        case .image, .mapView:
            return false // Images and maps should extend to edges
        default:
            return true // All other cells get horizontal padding
        }
    }
    
    private var shouldAddVerticalPadding: Bool {
        switch cell.type {
        case .image, .mapView:
            return false // Images and maps should extend to edges
        default:
            return true // All other cells get horizontal padding
        }
    }
    
    @ViewBuilder
    private var cellContent: some View {
        switch cell.type {
        case .text(let text, let style):
            DetailTextCell(text: text, style: style)
            
        case .email(let email, let label):
            DetailEmailCell(email: email, label: label)
            
        case .url(let url, let title):
            DetailURLCell(url: url, title: title)
            
        case .coordinates(let coordinate, let label):
            DetailCoordinatesCell(coordinate: coordinate, label: label)
            
        case .playaAddress(let address, let tappable):
            DetailPlayaAddressCell(address: address, tappable: tappable)
            
        case .distance(let distance):
            DetailDistanceCell(distance: distance)
            
        case .travelTime(let distance):
            DetailTravelTimeCell(distance: distance)
            
        case .userNotes(let notes):
            DetailUserNotesCell(notes: notes)
            
        case .audio(let artObject, let isPlaying):
            DetailAudioCell(artObject: artObject, isPlaying: isPlaying)

        case .audioTrack(let track, let isPlaying):
            DetailAudioTrackCell(track: track, isPlaying: isPlaying)
            
        case .relationship(let title, let type, _):
            DetailRelationshipCell(title: title, type: type)

        case .eventRelationship(let count, let hostName, _):
            DetailEventRelationshipCell(count: count, hostName: hostName)

        case .nextHostEvent(let title, let scheduleText, _, _):
            DetailNextHostEventCell(title: title, scheduleText: scheduleText)

        case .allHostEvents(let count, let hostName, _):
            DetailAllHostEventsCell(count: count, hostName: hostName)
            
        case .schedule(let attributedString):
            DetailScheduleCell(attributedString: attributedString)
            
        case .date(let date, let format):
            DetailDateCell(date: date, format: format)
            
        case .image(let image, let aspectRatio):
            DetailImageView(image: image, aspectRatio: aspectRatio)
            
        case .mapView(let dataObject, let metadata):
            DetailMapViewRepresentable(
                dataObject: dataObject,
                metadata: metadata
            ) {
                viewModel.handleCellTap(cell)
            }
            .frame(height: 200)

        case .mapAnnotation(let annotation, _):
            DetailMapViewRepresentable(annotation: annotation) {
                viewModel.handleCellTap(cell)
            }
            .frame(height: 200)
            
        case .landmark(let landmark):
            DetailLandmarkCell(landmark: landmark)
            
        case .eventType(let emoji, let label):
            DetailEventTypeCell(emoji: emoji, label: label)
            
        case .visitStatus(let status):
            DetailVisitStatusCell(
                currentStatus: status,
                onStatusChange: { newStatus in
                    Task { await viewModel.updateVisitStatus(newStatus) }
                }
            )

        case .viewHistory(let firstViewed, let lastViewed):
            DetailViewHistoryCell(firstViewed: firstViewed, lastViewed: lastViewed)
        }
    }
    
    private func isCellTappable(_ cellType: DetailCellType) -> Bool {
        switch cellType {
        case .email, .url, .coordinates, .audio, .audioTrack, .userNotes, .mapView, .mapAnnotation:
            return true
        case .relationship(_, _, let onTap):
            return onTap != nil
        case .eventRelationship(_, _, let onTap):
            return onTap != nil
        case .nextHostEvent(_, _, _, let onTap):
            return onTap != nil
        case .allHostEvents(_, _, let onTap):
            return onTap != nil
        case .playaAddress(_, let tappable):
            return tappable
        case .text, .distance, .travelTime, .schedule, .date, .landmark, .eventType:
            return false
        case .image:
            return true
        case .visitStatus, .viewHistory:
            return false
        }
    }
}

// MARK: - Individual Cell Views

struct DetailTextCell: View {
    let text: String
    let style: DetailTextStyle
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        Text(text)
            .font(fontForStyle(style))
            .foregroundColor(colorForStyle(style))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func fontForStyle(_ style: DetailTextStyle) -> Font {
        switch style {
        case .title:
            return .title2.bold()
        case .subtitle:
            return .headline
        case .body:
            return .body
        case .caption:
            return .caption
        case .headline:
            return .headline
        }
    }
    
    private func colorForStyle(_ style: DetailTextStyle) -> Color {
        switch style {
        case .title:
            return themeColors.primaryColor
        case .subtitle:
            return themeColors.detailColor
        case .body:
            return themeColors.secondaryColor
        case .caption:
            return themeColors.detailColor
        case .headline:
            return themeColors.primaryColor
        }
    }
}

struct DetailEmailCell: View {
    let email: String
    let label: String?
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "envelope")
                .foregroundColor(themeColors.primaryColor)
            VStack(alignment: .leading) {
                if let label = label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(themeColors.detailColor)
                }
                Text(email)
                    .foregroundColor(themeColors.primaryColor)
            }
            Spacer()
        }
    }
}

struct DetailURLCell: View {
    let url: URL
    let title: String
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(themeColors.primaryColor)
            Text(title)
                .foregroundColor(themeColors.primaryColor)
            Spacer()
        }
    }
}

struct DetailCoordinatesCell: View {
    let coordinate: CLLocationCoordinate2D
    let label: String
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "location")
                .foregroundColor(themeColors.primaryColor)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(themeColors.detailColor)
                Text("\(coordinate.latitude, specifier: "%.6f"), \(coordinate.longitude, specifier: "%.6f")")
                    .font(.system(.body, design: .monospaced))
            }
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(themeColors.primaryColor)
        }
    }
}

struct DetailPlayaAddressCell: View {
    let address: String
    let tappable: Bool
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OFFICIAL LOCATION")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "map")
                    .foregroundColor(tappable ? themeColors.primaryColor : themeColors.detailColor)
                Text(address)
                    .foregroundColor(tappable ? themeColors.primaryColor : themeColors.secondaryColor)
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeColors.primaryColor)
                        .font(.caption)
                }
            }
        }
    }
}

struct DetailDistanceCell: View {
    let distance: CLLocationDistance
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "ruler")
                .foregroundColor(themeColors.detailColor)
            Text("Distance: \(formattedDistance)")
                .foregroundColor(themeColors.detailColor)
            Spacer()
        }
    }
    
    private var formattedDistance: String {
        let meters = Measurement(value: distance, unit: UnitLength.meters)
        let feet = meters.converted(to: .feet)
        let miles = meters.converted(to: .miles)
        
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.unitOptions = .providedUnit
        
        if feet.value < 1000 {
            formatter.numberFormatter.maximumFractionDigits = 0
            return formatter.string(from: feet)
        } else {
            formatter.numberFormatter.maximumFractionDigits = 1
            return formatter.string(from: miles)
        }
    }
}

struct DetailTravelTimeCell: View {
    let distance: CLLocationDistance
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        if let attributedString = TTTLocationFormatter.brc_humanizedString(forDistance: distance) {
            HStack {
                Text(AttributedString(attributedString))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
    }
}

struct DetailUserNotesCell: View {
    let notes: String
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("USER NOTES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(themeColors.detailColor)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "pencil")
                    .foregroundColor(themeColors.primaryColor)
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(themeColors.primaryColor)
                if notes.isEmpty {
                    Text("Add your notes...")
                        .foregroundColor(themeColors.detailColor)
                        .italic()
                } else {
                    Text(notes)
                }
                Spacer()
            }
        }
    }
}

struct DetailAudioCell: View {
    let artObject: BRCArtObject
    let isPlaying: Bool
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .foregroundColor(themeColors.primaryColor)
                .font(.title2)
            Text("Audio Tour")
            Spacer()
        }
    }
}

struct DetailAudioTrackCell: View {
    let track: BRCAudioTourTrack
    let isPlaying: Bool
    @Environment(\.themeColors) var themeColors

    var body: some View {
        HStack {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .foregroundColor(themeColors.primaryColor)
                .font(.title2)
            Text("Audio Tour")
            Spacer()
        }
    }
}

struct DetailRelationshipCell: View {
    let title: String
    let type: RelationshipType
    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(themeColors.primaryColor)
                Text(title)
                    .foregroundColor(themeColors.primaryColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(themeColors.primaryColor)
                    .font(.caption)
            }
        }
    }

    private var sectionTitle: String {
        switch type {
        case .hostedBy:
            return "HOSTED BY CAMP"
        case .presentedBy:
            return "PRESENTED BY"
        case .relatedCamp:
            return "RELATED CAMP"
        case .relatedArt:
            return "RELATED ART"
        case .relatedEvent:
            return "RELATED EVENT"
        }
    }
}

struct DetailEventRelationshipCell: View {
    let count: Int
    let hostName: String
    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OTHER EVENTS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(themeColors.primaryColor)
                Text("Hosted Events")
                    .foregroundColor(themeColors.primaryColor)
                Spacer()
                Text("\(count)")
                    .foregroundColor(themeColors.detailColor)
                Image(systemName: "chevron.right")
                    .foregroundColor(themeColors.primaryColor)
                    .font(.caption)
            }
        }
    }
}

struct DetailScheduleCell: View {
    let attributedString: NSAttributedString
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)
            
            Text(AttributedString(attributedString))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(themeColors.primaryColor)
        }
    }
}

struct DetailDateCell: View {
    let date: Date
    let format: String
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(themeColors.detailColor)
            Text(formattedDate)
                .foregroundColor(themeColors.secondaryColor)
            Spacer()
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone.burningManTimeZone
        return formatter.string(from: date)
    }
}

struct DetailNextHostEventCell: View {
    let title: String
    let scheduleText: String
    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT EVENT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeColors.primaryColor)
                        .lineLimit(2)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(themeColors.primaryColor)
                        .font(.caption)
                }

                if !scheduleText.isEmpty {
                    Text(scheduleText)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }
        }
    }
}

struct DetailAllHostEventsCell: View {
    let count: Int
    let hostName: String
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(themeColors.primaryColor)
            
            Text("See all \(count) events from \(hostName)")
                .foregroundColor(themeColors.primaryColor)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(themeColors.primaryColor)
                .font(.caption)
        }
    }
}

struct DetailLandmarkCell: View {
    let landmark: String
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LANDMARK")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "flag")
                    .foregroundColor(themeColors.detailColor)
                Text(landmark)
                    .foregroundColor(themeColors.secondaryColor)
                Spacer()
            }
        }
    }
}

struct DetailEventTypeCell: View {
    let emoji: String
    let label: String
    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVENT TYPE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)

            Text("\(emoji) \(label)")
                .foregroundColor(themeColors.secondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DetailVisitStatusCell: View {
    let currentStatus: BRCVisitStatus
    let onStatusChange: (BRCVisitStatus) -> Void
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VISIT STATUS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)
            
            Menu {
                ForEach(BRCVisitStatus.allCases, id: \.self) { status in
                    Button(action: {
                        onStatusChange(status)
                    }) {
                        Label(status.displayString, systemImage: status.iconName)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: currentStatus.iconName)
                        .foregroundColor(currentStatus.color)
                    Text(currentStatus.displayString)
                        .foregroundColor(themeColors.primaryColor)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(themeColors.primaryColor)
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct DetailViewHistoryCell: View {
    let firstViewed: Date?
    let lastViewed: Date?
    @Environment(\.themeColors) var themeColors

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryColor)
                Text("View History")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.secondaryColor)
            }

            if let lastViewed {
                Text("Last viewed: \(Self.formatter.string(from: lastViewed))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            if let firstViewed {
                Text("First viewed: \(Self.formatter.string(from: firstViewed))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}
