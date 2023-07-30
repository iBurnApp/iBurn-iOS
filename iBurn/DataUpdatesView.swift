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
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
    
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
                .toggleStyle(SwitchToggleStyle(tint: .primary))
                Button("Check for Updates") {
                    viewModel.didTapCheckForUpdates()
                }
            }
            Section {
                ForEach(viewModel.allUpdateInfo, id: \.self) { update in
                    VStack(alignment: .leading) {
                        Text("\(update.fileName)")
                        Group {
                            Text("Last updated: \(Self.dateFormatter.string(from: update.lastUpdated))")
                            Text("Last fetched: \(Self.dateFormatter.string(from: update.fetchDate))")
                            Text("Status: \(update.fetchStatus.description)")
                        }
                        .font(.caption2)
                    }
                }
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

private final class DataUpdatesViewModel: ObservableObject {
    @Published var showConfirmationAlert: Bool = false
    @Published var dataUpdatesEnabled: Bool = false
    @Published var isLoading: Bool = false
    private var cancellables: Set<AnyCancellable> = .init()
    private var handlerDelegate: YapViewHandlerDelegateHandler?
    private let handler: YapViewHandler
    @Published var allUpdateInfo: [BRCUpdateInfo] = []
    
    init() {
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
    
    func refreshFromDatabase() {
        allUpdateInfo = handler.allObjects(in: 0)
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

struct DataUpdatesView_Previews: PreviewProvider {
    private static let viewModel = DataUpdatesViewModel()
    static var previews: some View {
        DataUpdatesView(viewModel: viewModel)
    }
}
