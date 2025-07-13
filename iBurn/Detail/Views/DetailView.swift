//
//  DetailView.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    init(viewModel: DetailViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header with image if available
                if let headerCell = viewModel.cells.first(where: { 
                    if case .image = $0.type { return true }
                    return false
                }) {
                    Button(action: {
                        viewModel.handleCellTap(headerCell)
                    }) {
                        DetailHeaderView(cell: headerCell, viewModel: viewModel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Content sections
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.cells) { cell in
                        // Skip image cells since they're handled above
                        if case .image = cell.type {
                            EmptyView()
                        } else {
                            DetailCellView(cell: cell, viewModel: viewModel)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .background(Color(Appearance.currentColors.backgroundColor))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(viewModel.dataObject.title)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                        .foregroundColor(viewModel.metadata.isFavorite ? .pink : .secondary)
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

struct DetailHeaderView: View {
    let cell: DetailCell
    let viewModel: DetailViewModel
    
    var body: some View {
        if case .image(let image, let aspectRatio) = cell.type {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxHeight: 300)
                .clipped()
        }
    }
}

struct DetailCellView: View {
    let cell: DetailCell
    let viewModel: DetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isCellTappable(cell.type) {
                Button(action: {
                    viewModel.handleCellTap(cell)
                }) {
                    cellContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cellContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
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
            
        case .schedule(let attributedString):
            DetailScheduleCell(attributedString: attributedString)
            
        case .date(let date, let format):
            DetailDateCell(date: date, format: format)
            
        default:
            // Placeholder for other cell types
            Text("Cell type not implemented yet")
                .foregroundColor(.secondary)
        }
    }
    
    private func isCellTappable(_ cellType: DetailCellType) -> Bool {
        switch cellType {
        case .email, .url, .coordinates, .relationship, .eventRelationship, .audio, .userNotes:
            return true
        case .playaAddress(_, let tappable):
            return tappable
        case .text, .distance, .schedule, .date, .image:
            return false
        }
    }
}

// MARK: - Individual Cell Views

struct DetailTextCell: View {
    let text: String
    let style: DetailTextStyle
    
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
            return .primary
        case .subtitle:
            return .secondary
        case .body:
            return .primary
        case .caption:
            return .secondary
        case .headline:
            return .primary
        }
    }
}

struct DetailEmailCell: View {
    let email: String
    let label: String?
    
    var body: some View {
        HStack {
            Image(systemName: "envelope")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                if let label = label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(email)
                    .foregroundColor(.blue)
            }
            Spacer()
        }
    }
}

struct DetailURLCell: View {
    let url: URL
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.blue)
            Text(title)
                .foregroundColor(.blue)
            Spacer()
        }
    }
}

struct DetailCoordinatesCell: View {
    let coordinate: CLLocationCoordinate2D
    let label: String
    
    var body: some View {
        HStack {
            Image(systemName: "location")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(coordinate.latitude, specifier: "%.6f"), \(coordinate.longitude, specifier: "%.6f")")
                    .font(.system(.body, design: .monospaced))
            }
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
        }
    }
}

struct DetailPlayaAddressCell: View {
    let address: String
    let tappable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OFFICIAL LOCATION")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "map")
                    .foregroundColor(tappable ? .blue : .secondary)
                Text(address)
                    .foregroundColor(tappable ? .blue : .primary)
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
    }
}

struct DetailDistanceCell: View {
    let distance: CLLocationDistance
    
    var body: some View {
        HStack {
            Image(systemName: "ruler")
                .foregroundColor(.secondary)
            Text("Distance: \(distance, specifier: "%.0f") meters")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct DetailUserNotesCell: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("USER NOTES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.blue)
                if notes.isEmpty {
                    Text("Add your notes...")
                        .foregroundColor(.secondary)
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
    
    var body: some View {
        HStack {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            Text("Audio Tour")
            Spacer()
        }
    }
}

struct DetailRelationshipCell: View {
    let object: BRCDataObject
    let type: RelationshipType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
                Text(object.title)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OTHER EVENTS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Hosted Events")
                    .foregroundColor(.blue)
                Spacer()
                Text("\(events.count)")
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
    }
}

struct DetailScheduleCell: View {
    let attributedString: NSAttributedString
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(AttributedString(attributedString))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.orange)
        }
    }
}

struct DetailDateCell: View {
    let date: Date
    let format: String
    
    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
            Text(formattedDate)
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
