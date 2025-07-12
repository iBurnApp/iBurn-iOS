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
                // Header with image/map if available
                if let headerCell = viewModel.cells.first(where: { 
                    if case .image = $0.type { return true }
                    return false
                }) {
                    DetailHeaderView(cell: headerCell, viewModel: viewModel)
                }
                
                // Content cells
                ForEach(viewModel.cells) { cell in
                    DetailCellView(cell: cell, viewModel: viewModel)
                        .onTapGesture {
                            viewModel.handleCellTap(cell)
                        }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if viewModel.dataObject is BRCEventObject {
                        Button("Add to Calendar") {
                            viewModel.showEventEditor()
                        }
                        .font(.caption)
                    }
                    
                    Button(action: {
                        Task { await viewModel.toggleFavorite() }
                    }) {
                        Image(systemName: viewModel.metadata.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(.pink)
                    }
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
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.horizontal)
        .padding(.vertical, 4)
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
        HStack {
            Image(systemName: "note.text")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if notes.isEmpty {
                    Text("Add your notes...")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(notes)
                }
            }
            Spacer()
            Image(systemName: "pencil")
                .foregroundColor(.blue)
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
        HStack {
            Image(systemName: "arrow.right.circle")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(titleForRelationshipType(type))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(object.title)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.caption)
        }
    }
    
    private func titleForRelationshipType(_ type: RelationshipType) -> String {
        switch type {
        case .hostedBy(let name):
            return "Hosted by \(name)"
        case .presentedBy(let name):
            return "Presented by \(name)"
        case .relatedCamp:
            return "Related Camp"
        case .relatedArt:
            return "Related Art"
        case .relatedEvent:
            return "Related Event"
        }
    }
}

struct DetailEventRelationshipCell: View {
    let events: [BRCEventObject]
    let hostName: String
    
    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text("Events at \(hostName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(events.count) events")
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.caption)
        }
    }
}

struct DetailScheduleCell: View {
    let attributedString: NSAttributedString
    
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.secondary)
            VStack(alignment: .leading) {
                Text("Schedule")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(AttributedString(attributedString))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
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