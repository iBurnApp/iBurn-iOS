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
        let playaDB = BRCAppDelegate.shared.dependencies.playaDB
        return DataUpdatesViewController(playaDB: playaDB)
    }
}

private final class DataUpdatesViewController: UIHostingController<DataUpdatesView> {
    private let viewModel: DataUpdatesViewModel

    init(playaDB: PlayaDB) {
        self.viewModel = .init(playaDB: playaDB)
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
                        .foregroundColor(status.contains("failed") ? .red : .green)
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
        Section(header: Text("YapDatabase")) {
            VStack(alignment: .leading) {
                Text("update.json")
                Text("Last checked: \(viewModel.lastUpdateCheck.flatMap { Self.dateFormatter.string(from: $0)} ?? "Never")")
                    .font(.caption2)
            }
            ForEach(viewModel.allUpdateInfo, id: \.self) { update in
                VStack(alignment: .leading) {
                    Text("\(update.fileName)")
                    Group {
                        Text("Updated in update.json: \(Self.dateFormatter.string(from: update.lastUpdated))")
                        Text("Fetched from server:  \(update.fetchDate.flatMap { Self.dateFormatter.string(from: $0)} ?? "Never")")
                        Text("Checked for update: \(update.lastCheckedDate.flatMap { Self.dateFormatter.string(from: $0)} ?? "Never")")
                        Text("Loaded into app: \(update.ingestionDate.flatMap { Self.dateFormatter.string(from: $0)} ?? "Never")")
                        Text("Status: \(update.fetchStatus.description)")
                    }
                    .font(.caption2)
                }
            }
        }
        Section(header: Text("PlayaDB (GRDB)")) {
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
    private var cancellables: Set<AnyCancellable> = .init()
    private var handlerDelegate: YapViewHandlerDelegateHandler?
    private let handler: YapViewHandler
    @Published var allUpdateInfo: [BRCUpdateInfo] = []
    @Published var playaDBUpdateInfo: [UpdateInfo] = []
    private let playaDB: PlayaDB
    private var updateInfoObservation: PlayaDBObservationToken?

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
        handler = YapViewHandler(viewName: BRCDatabaseManager.updateInfoViewName)
        $dataUpdatesEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { value in
                UserDefaults.areDownloadsDisabled = !value
            }
            .store(in: &cancellables)
        self.handlerDelegate = .init(didSetupMappingsBlock: { [weak self] handler in
            self?.refreshFromDatabase()
        }, didReceiveChangesBlock: { [weak self] handler, sectionChanges, rowChanges in
            self?.refreshFromDatabase()
        })
        handler.delegate = handlerDelegate
        refreshFromDatabase()

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

    func didTapResetConfirmation() {
        isLoading = true
        playaDBStatus = "Resetting Yap..."
        Task {
            // Yap reset on background queue
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().async {
                    BRCAppDelegate.shared.dataImporter.resetUpdates()
                    BRCAppDelegate.shared.preloadExistingData()
                    continuation.resume()
                }
            }
            playaDBStatus = "Yap done. Re-importing PlayaDB..."
            // PlayaDB re-import
            await reimportPlayaDB()
            isLoading = false
        }
    }

    func didTapCheckForUpdates() {
        guard let updateURL = URL(string: kBRCUpdatesURLString) else {
            return
        }
        // allow forcing update check
        UserDefaults.lastUpdateCheck = nil
        self.isLoading = true
        playaDBStatus = "Checking for updates..."
        Task {
            // Yap update
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                BRCAppDelegate.shared.dataImporter.loadUpdates(from: updateURL) { result in
                    NSLog("UPDATE COMPLETE: \(result)")
                    continuation.resume()
                }
            }
            refreshLastUpdateCheck()
            playaDBStatus = "Yap done. Re-importing PlayaDB..."
            // PlayaDB re-import
            await reimportPlayaDB()
            isLoading = false
        }
    }

    func onAppear() {
        dataUpdatesEnabled = !UserDefaults.areDownloadsDisabled
        refreshLastUpdateCheck()
    }

    func refreshLastUpdateCheck() {
        lastUpdateCheck = UserDefaults.lastUpdateCheck
    }

    func refreshFromDatabase() {
        allUpdateInfo = handler.allObjects(in: 0)
    }

    /// Re-import PlayaDB from the bundled data to keep both databases in sync.
    /// UI updates reactively via the GRDB observation — no manual refresh needed.
    private func reimportPlayaDB() async {
        let dataBundle = Bundle.brc_dataBundle
        do {
            playaDBStatus = "Loading bundle data..."
            let artData = try BundleDataLoader.loadArt(from: dataBundle)
            let campData = try BundleDataLoader.loadCamps(from: dataBundle)
            let eventData = try BundleDataLoader.loadEvents(from: dataBundle)
            let mvData = try? BundleDataLoader.loadMutantVehicles(from: dataBundle)
            playaDBStatus = "Importing into PlayaDB..."
            try await playaDB.importFromData(
                artData: artData,
                campData: campData,
                eventData: eventData,
                mvData: mvData
            )
            playaDBStatus = "PlayaDB re-import complete"
        } catch {
            playaDBStatus = "PlayaDB re-import failed: \(error.localizedDescription)"
            print("PlayaDB: Re-import failed: \(error)")
        }
    }
}

final class YapViewHandlerDelegateHandler: NSObject, YapViewHandlerDelegate {
    init(didSetupMappingsBlock: @escaping YapViewHandlerDelegateHandler.SetupMappingsBlock, didReceiveChangesBlock: @escaping YapViewHandlerDelegateHandler.DidReceiveChangesBlock) {
        self.didSetupMappingsBlock = didSetupMappingsBlock
        self.didReceiveChangesBlock = didReceiveChangesBlock
    }
    
    typealias SetupMappingsBlock = (_ handler: YapViewHandler) -> Void
    var didSetupMappingsBlock: SetupMappingsBlock
    typealias DidReceiveChangesBlock = (_ handler: YapViewHandler, _ sectionChanges: [YapDatabaseViewSectionChange], _ rowChanges: [YapDatabaseViewRowChange]) -> Void
    var didReceiveChangesBlock: DidReceiveChangesBlock
    
    func didSetupMappings(_ handler: YapViewHandler) {
        didSetupMappingsBlock(handler)
    }
    
    func didReceiveChanges(_ handler: YapViewHandler, sectionChanges: [YapDatabaseViewSectionChange], rowChanges: [YapDatabaseViewRowChange]) {
        didReceiveChangesBlock(handler, sectionChanges, rowChanges)
    }
}

// Preview requires both YapDB and PlayaDB infrastructure
