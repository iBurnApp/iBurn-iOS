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
        .navigationTitle(viewModel.dataObject.title)
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
                if viewModel.dataObject is BRCEventObject {
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
                    Image(systemName: viewModel.metadata.isFavorite ? "heart.fill" : "heart")
                        .font(.body)
                        .accessibilityLabel(viewModel.metadata.isFavorite ?  "Remove Favorite" : "Add Favorite")
                        .foregroundColor(viewModel.metadata.isFavorite ? .pink : themeColors.detailColor)
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
            
        case .userNotes(let notes):
            DetailUserNotesCell(notes: notes)
            
        case .audio(let artObject, let isPlaying):
            DetailAudioCell(artObject: artObject, isPlaying: isPlaying)
            
        case .relationship(let object, let type):
            DetailRelationshipCell(object: object, type: type)
            
        case .eventRelationship(let events, let hostName):
            DetailEventRelationshipCell(events: events, hostName: hostName)
            
        case .nextHostEvent(let nextEvent, let hostName):
            DetailNextHostEventCell(nextEvent: nextEvent, hostName: hostName)
            
        case .allHostEvents(let count, let hostName):
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
            
        case .landmark(let landmark):
            DetailLandmarkCell(landmark: landmark)
            
        case .eventType(let eventType):
            DetailEventTypeCell(eventType: eventType)
            
        case .visitStatus(let status):
            DetailVisitStatusCell(
                currentStatus: status,
                onStatusChange: { newStatus in
                    Task { await viewModel.updateVisitStatus(newStatus) }
                }
            )
        }
    }
    
    private func isCellTappable(_ cellType: DetailCellType) -> Bool {
        switch cellType {
        case .email, .url, .coordinates, .relationship, .eventRelationship, .nextHostEvent, .allHostEvents, .audio, .userNotes, .mapView:
            return true
        case .playaAddress(_, let tappable):
            return tappable
        case .text, .distance, .schedule, .date, .landmark, .eventType:
            return false
        case .image:
            return true
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
            Text("Distance: \(distance, specifier: "%.0f") meters")
                .foregroundColor(themeColors.detailColor)
            Spacer()
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

struct DetailRelationshipCell: View {
    let object: BRCDataObject
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
                Text(object.title)
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
    let events: [BRCEventObject]
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
                Text("\(events.count)")
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
        return formatter.string(from: date)
    }
}

struct DetailNextHostEventCell: View {
    let nextEvent: BRCEventObject
    let hostName: String
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
                    Text(nextEvent.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeColors.primaryColor)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeColors.primaryColor)
                        .font(.caption)
                }
                
                if let startDate = nextEvent.startDate as Date?,
                   let endDate = nextEvent.endDate as Date? {
                    Text(formatEventTimeAndDuration(startDate: startDate, endDate: endDate))
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryColor)
                }
                
                if let description = nextEvent.detailDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(themeColors.detailColor)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private func formatEventTimeAndDuration(startDate: Date, endDate: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        var timeString: String
        
        // Format day and time
        if calendar.isDateInToday(startDate) {
            timeString = "Today at \(timeFormatter.string(from: startDate))"
        } else if calendar.isDateInTomorrow(startDate) {
            timeString = "Tomorrow at \(timeFormatter.string(from: startDate))"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE M/d" // e.g., "Friday 8/25"
            timeString = "\(dayFormatter.string(from: startDate)) at \(timeFormatter.string(from: startDate))"
        }
        
        // Add duration
        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        
        var durationString: String
        if hours > 0 && minutes > 0 {
            durationString = "\(hours)h \(minutes)m"
        } else if hours > 0 {
            durationString = "\(hours)h"
        } else {
            durationString = "\(minutes)m"
        }
        
        return "\(timeString) • \(durationString)"
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
    let eventType: BRCEventType
    @Environment(\.themeColors) var themeColors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVENT TYPE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.detailColor)
                .textCase(.uppercase)
            
            Text("\(eventType.emoji) \(eventType.displayString)")
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

