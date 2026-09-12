//
//  DataUpdatesView.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/23.
//  Copyright © 2023 iBurn. All rights reserved.
//

import SwiftUI
import Combine
import struct PlayaDB.UpdateInfo
import PlayaDB
import PlayaAPI

final class DataUpdatesFactory {
    @MainActor
    static func makeViewController() -> UIViewController {
        let dependencies = BRCAppDelegate.shared.dependencies
        return DataUpdatesViewController(
            playaDB: dependencies.playaDB,
            dataUpdateService: dependencies.dataUpdateService
        )
    }
}

private final class DataUpdatesViewController: UIHostingController<DataUpdatesView> {
    private let viewModel: DataUpdatesViewModel

    init(playaDB: PlayaDB, dataUpdateService: DataUpdateService) {
        self.viewModel = .init(playaDB: playaDB, dataUpdateService: dataUpdateService)
        super.init(rootView: .init(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct DataUpdatesView: View {
    @ObservedObject var viewModel: DataUpdatesViewModel
    static let dateFormatter: DateFormatter = .shortDateAndTime

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
            if let status = viewModel.playaDBStatus {
                Section {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(viewModel.statusIsError ? .red : .green)
                }
            }
            Section {
                Toggle(isOn: $viewModel.dataUpdatesEnabled) {
                    Text("Automatic Updates")
                    if YearSettings.isEventOver {
                        Text("Event is over, auto-updates disabled.")
                            .font(.caption2)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .primary))
                .disabled(YearSettings.isEventOver)
                Button("Check for Updates") {
                    viewModel.didTapCheckForUpdates()
                }
            }
            Section {
                Toggle(isOn: $viewModel.showNerdyStats.animation()) {
                    Text("Show Nerdy Stats")
                }
                .toggleStyle(SwitchToggleStyle(tint: .primary))
            }
            if viewModel.showNerdyStats {
                nerdyStats
            }
            Section {
                Button("Reset to Bundled Data") {
                    viewModel.didTapReset()
                }.accentColor(Color(.systemRed))
            }
        }
        .accentColor(.primary)
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

private extension DataUpdatesView {
    @ViewBuilder
    var nerdyStats: some View {
        Section(header: Text("Data")) {
            VStack(alignment: .leading) {
                Text("update.json")
                Text("Last checked: \(viewModel.lastUpdateCheck.flatMap { Self.dateFormatter.string(from: $0)} ?? "Never")")
                    .font(.caption2)
            }
            if viewModel.playaDBUpdateInfo.isEmpty {
                Text("Not seeded yet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.playaDBUpdateInfo, id: \.dataType) { info in
                    VStack(alignment: .leading) {
                        Text(info.dataType.capitalized)
                        Group {
                            Text("Count: \(info.totalCount)")
                            Text("Status: \(info.fetchStatus)")
                            Text("Last updated: \(Self.dateFormatter.string(from: info.lastUpdated))")
                            Text("Fetched from server: \(info.fetchDate.flatMap { Self.dateFormatter.string(from: $0) } ?? "Never")")
                            Text("Checked for update: \(info.lastCheckedDate.flatMap { Self.dateFormatter.string(from: $0) } ?? "Never")")
                            Text("Loaded into app: \(info.ingestionDate.flatMap { Self.dateFormatter.string(from: $0) } ?? "Never")")
                        }
                        .font(.caption2)
                    }
                }
            }
        }
    }
}

private final class DataUpdatesViewModel: ObservableObject {
    @Published var showConfirmationAlert: Bool = false
    @Published var dataUpdatesEnabled: Bool = false
    @Published var isLoading: Bool = false
    @Published var showNerdyStats: Bool = false
    @Published var lastUpdateCheck: Date?
    @Published var playaDBStatus: String?
    @Published var statusIsError: Bool = false
    @Published var playaDBUpdateInfo: [UpdateInfo] = []
    private var cancellables: Set<AnyCancellable> = .init()
    private let playaDB: PlayaDB
    private let dataUpdateService: DataUpdateService
    private var updateInfoObservation: PlayaDBObservationToken?

    init(playaDB: PlayaDB, dataUpdateService: DataUpdateService) {
        self.playaDB = playaDB
        self.dataUpdateService = dataUpdateService
        $dataUpdatesEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { value in
                UserDefaults.areDownloadsDisabled = !value
            }
            .store(in: &cancellables)

        // Observe PlayaDB update info reactively
        updateInfoObservation = playaDB.observeUpdateInfo(
            onChange: { [weak self] infos in
                self?.playaDBUpdateInfo = infos
            },
            onError: { error in
                print("PlayaDB UpdateInfo observation error: \(error)")
            }
        )
    }

    deinit {
        updateInfoObservation?.cancel()
    }

    func didTapReset() {
        showConfirmationAlert = true
    }

    /// Clears every downloaded update and re-imports the JSON bundled with the app.
    func didTapResetConfirmation() {
        isLoading = true
        setStatus("Resetting to bundled data...", isError: false)
        Task { @MainActor in
            do {
                try await dataUpdateService.resetToBundledData()
                setStatus("Reset complete", isError: false)
            } catch {
                setStatus("Reset failed: \(error.localizedDescription)", isError: true)
            }
            lastUpdateCheck = dataUpdateService.lastUpdateCheck
            isLoading = false
        }
    }

    /// Forced check: ignores both the once-per-day throttle and the auto-update toggle.
    func didTapCheckForUpdates() {
        isLoading = true
        setStatus("Checking for updates...", isError: false)
        Task { @MainActor in
            do {
                let outcome = try await dataUpdateService.checkForUpdates(force: true)
                setStatus(Self.description(for: outcome), isError: false)
            } catch {
                setStatus("Update failed: \(error.localizedDescription)", isError: true)
            }
            lastUpdateCheck = dataUpdateService.lastUpdateCheck
            isLoading = false
        }
    }

    func onAppear() {
        dataUpdatesEnabled = !UserDefaults.areDownloadsDisabled
        Task { @MainActor in
            lastUpdateCheck = dataUpdateService.lastUpdateCheck
        }
    }

    private func setStatus(_ status: String, isError: Bool) {
        playaDBStatus = status
        statusIsError = isError
    }

    private static func description(for outcome: DataUpdateOutcome) -> String {
        switch outcome {
        case .alreadyRunning:
            return "An update is already in progress"
        case .skippedDisabled:
            return "Automatic updates are disabled"
        case .skippedThrottled:
            return "Checked recently, skipping"
        case .upToDate:
            return "Already up to date"
        case .updated(let types):
            let names = types.map { $0.displayName }.joined(separator: ", ")
            return "Updated: \(names)"
        }
    }
}
