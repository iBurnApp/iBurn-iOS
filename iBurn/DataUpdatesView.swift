//
//  DataUpdatesView.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/23.
//  Copyright © 2023 iBurn. All rights reserved.
//

import SwiftUI
import Combine

final class DataUpdatesFactory {
    static func makeViewController() -> UIViewController {
        DataUpdatesViewController()
    }
}

private final class DataUpdatesViewController: UIHostingController<DataUpdatesView> {
    private let viewModel: DataUpdatesViewModel
    
    init() {
        self.viewModel = .init()
        super.init(rootView: .init(viewModel: viewModel))
    }
    
    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct DataUpdatesView: View {
    @ObservedObject var viewModel: DataUpdatesViewModel
    
    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Text("Loading...")
                        ProgressView()
                    }
                }
            }
            Section {
                Toggle(isOn: $viewModel.dataUpdatesEnabled) {
                    Text("Automatic Updates")
                }
                Button("Check for Updates") {
                    viewModel.didTapCheckForUpdates()
                }
            }
            Section {
                Button("Reset To Bundled Data") {
                    viewModel.didTapReset()
                }.accentColor(Color(.systemRed))
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .navigationTitle("Data Updates")
        .alert(isPresented: $viewModel.showConfirmationAlert) {
            Alert(
                title: Text("Reset to bundled data?"),
                message: Text("This will clear out any downloaded updates and reset to the data that was originally bundled with the app download. Only do this if you are experiencing major issues, because you won't be able to re-download updated data if you're on playa without an internet connection. This action cannot be undone."),
                primaryButton: .destructive(Text("Reset"), action: {
                    viewModel.didTapResetConfirmation()
                }),
                secondaryButton: .cancel()
            )
        }
    }
}

private final class DataUpdatesViewModel: ObservableObject {
    @Published var showConfirmationAlert: Bool = false
    @Published var dataUpdatesEnabled: Bool = false
    @Published var isLoading: Bool = false
    private var cancellables: Set<AnyCancellable> = .init()
    
    init() {
        $dataUpdatesEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { value in
                UserDefaults.areDownloadsDisabled = !value
            }
            .store(in: &cancellables)
    }

    
    func didTapReset() {
        showConfirmationAlert = true
    }
    
    func didTapResetConfirmation() {
        isLoading = true
        DispatchQueue.global().async {
            BRCAppDelegate.shared.dataImporter.resetUpdates()
            BRCAppDelegate.shared.preloadExistingData()
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    func didTapCheckForUpdates() {
        guard let updateURL = URL(string: kBRCUpdatesURLString) else {
            return
        }
        self.isLoading = true
        BRCAppDelegate.shared.dataImporter.loadUpdates(from: updateURL) { result in
            NSLog("UPDATE COMPLETE: \(result)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    func onAppear() {
        dataUpdatesEnabled = !UserDefaults.areDownloadsDisabled
    }
}

struct DataUpdatesView_Previews: PreviewProvider {
    private static let viewModel = DataUpdatesViewModel()
    static var previews: some View {
        DataUpdatesView(viewModel: viewModel)
    }
}
