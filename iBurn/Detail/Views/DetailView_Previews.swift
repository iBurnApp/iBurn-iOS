//
//  DetailView_Previews.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

// MARK: - Preview Factory

// Mock coordinator for previews
class MockDetailActionCoordinator: DetailActionCoordinator {
    func handle(_ action: DetailAction) {
        print("Preview action: \(action)")
    }
}

extension DetailViewModel {
    static func createPreview(with dataObject: BRCDataObject) -> DetailViewModel {
        return DetailViewModel(
            dataObject: dataObject,
            dataService: MockDetailDataService(),
            audioService: MockAudioService(),
            locationService: MockLocationService(),
            coordinator: MockDetailActionCoordinator()
        )
    }
}

// MARK: - SwiftUI Previews

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Art object preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.artObject))
            }
            .previewDisplayName("Art Detail")
            
            // Camp object preview  
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.campObject))
            }
            .previewDisplayName("Camp Detail")
            
            // Event object preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.eventObject))
            }
            .previewDisplayName("Event Detail")
            
            // Art with audio preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.artObjectWithAudio))
            }
            .previewDisplayName("Art with Audio")
            
            // Dark mode preview
            NavigationView {
                DetailView(viewModel: DetailViewModel.createPreview(with: MockDataObjects.artObject))
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            // Favorited item preview
            NavigationView {
                DetailView(viewModel: {
                    let viewModel = DetailViewModel.createPreview(with: MockDataObjects.eventObject)
                    viewModel.metadata.isFavorite = true
                    return viewModel
                }())
            }
            .previewDisplayName("Favorited Event")
            
            // Item with notes preview
            NavigationView {
                DetailView(viewModel: {
                    let viewModel = DetailViewModel.createPreview(with: MockDataObjects.campObject)
                    viewModel.metadata.userNotes = "Great coffee here! Really friendly people. Don't miss the 3pm ceremony."
                    return viewModel
                }())
            }
            .previewDisplayName("Camp with Notes")
        }
    }
}

// MARK: - Individual Cell Previews

struct DetailCellView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = DetailViewModel.createPreview(with: MockDataObjects.artObject)
        
        VStack(spacing: 16) {
            // Text cells
            DetailCellView(cell: DetailCell(.text("Sample Art Installation", style: .title)), viewModel: mockViewModel)
            DetailCellView(cell: DetailCell(.text("This is a sample description", style: .body)), viewModel: mockViewModel)
            DetailCellView(cell: DetailCell(.text("Artist: John Doe", style: .subtitle)), viewModel: mockViewModel)
            
            // Interactive cells
            DetailCellView(cell: DetailCell(.email("artist@example.com", label: "Contact")), viewModel: mockViewModel)
            DetailCellView(cell: DetailCell(.url(URL(string: "https://example.com")!, title: "Website")), viewModel: mockViewModel)
            DetailCellView(cell: DetailCell(.playaAddress("3:00 & 500'", tappable: true)), viewModel: mockViewModel)
            
            // User notes
            DetailCellView(cell: DetailCell(.userNotes("This is a great art piece!")), viewModel: mockViewModel)
            DetailCellView(cell: DetailCell(.userNotes("")), viewModel: mockViewModel)
            
            Spacer()
        }
        .padding()
        .previewDisplayName("Individual Cells")
    }
}

// MARK: - Loading State Preview

struct DetailView_LoadingState_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(viewModel: {
                let viewModel = DetailViewModel.createPreview(with: MockDataObjects.artObject)
                viewModel.isLoading = true
                return viewModel
            }())
        }
        .previewDisplayName("Loading State")
    }
}

// MARK: - Error State Preview

struct DetailView_ErrorState_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DetailView(viewModel: {
                let viewModel = DetailViewModel.createPreview(with: MockDataObjects.artObject)
                viewModel.error = DetailError.updateFailed
                return viewModel
            }())
        }
        .previewDisplayName("Error State")
    }
}