//
//  MoreViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/13/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import StoreKit
import SwiftUI

protocol ReusableCell {
    static var reuseIdentifier: String { get }
}

extension UITableView {
    func dequeueReusableCell<T: UITableViewCell & ReusableCell>(_ cellClass: T.Type, for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Failed to dequeue cell of type \(T.self) with identifier \(T.reuseIdentifier)")
        }
        return cell
    }
}

class MoreViewController: UITableViewController, SKStoreProductViewControllerDelegate {
    
    // MARK: - Initialization
    
    init() {
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    enum Section: Int, CaseIterable {
        case detailViews = 0
        case customization = 1
        case contact = 2
        case extras = 3
        
        var title: String? {
            switch self {
            case .extras: return "Extras"
            default: return nil
            }
        }
    }
    
    enum DetailViewsRow: Int, CaseIterable {
        case art = 0
        case camps = 1
        case audioTour = 2
        case locationHistory = 3
    }
    
    enum CustomizationRow: Int, CaseIterable {
        case appearance = 0
    }
    
    enum ContactRow: Int, CaseIterable {
        case feedback = 0
        case share = 1
        case rate = 2
    }
    
    enum ExtrasRow: Int, CaseIterable {
        case unlock = 0
        case credits = 1
        case debugShowOnboarding = 2
        case dataUpdates = 3
        case navigationMode = 4
        #if DEBUG
        case featureFlags = 5
        #endif
    }
    
    enum CellType {
        case detailViews(DetailViewsRow)
        case customization(CustomizationRow)
        case contact(ContactRow)
        case extras(ExtrasRow)
        
        init?(indexPath: IndexPath) {
            guard let section = Section(rawValue: indexPath.section) else { return nil }
            
            switch section {
            case .detailViews:
                guard let row = DetailViewsRow(rawValue: indexPath.row) else { return nil }
                self = .detailViews(row)
            case .customization:
                guard let row = CustomizationRow(rawValue: indexPath.row) else { return nil }
                self = .customization(row)
            case .contact:
                guard let row = ContactRow(rawValue: indexPath.row) else { return nil }
                self = .contact(row)
            case .extras:
                guard let row = ExtrasRow(rawValue: indexPath.row) else { return nil }
                self = .extras(row)
            }
        }
    }
    
    
    private let versionLabel: UILabel = {
        let label = UILabel()
        label.text = {
            guard let dictionary = Bundle.main.infoDictionary,
                  let version = dictionary["CFBundleShortVersionString"] as? String,
                  let build = dictionary["CFBundleVersion"] as? String else {
                return ""
            }
            return "Version \(version) (\(build))"
        }()
        label.sizeToFit()
        label.frame.size.height += 20
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = .systemGray
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "More"
        
        // Register custom cell classes
        tableView.register(MoreTableViewCell.self, forCellReuseIdentifier: MoreTableViewCell.reuseIdentifier)
        tableView.register(MoreSubtitleCell.self, forCellReuseIdentifier: MoreSubtitleCell.reuseIdentifier)
        tableView.register(MoreSwitchCell.self, forCellReuseIdentifier: MoreSwitchCell.reuseIdentifier)
        
        self.tableView.tableFooterView = versionLabel
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITableViewDelegate & DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        switch section {
        case .detailViews: return DetailViewsRow.allCases.count
        case .customization: return CustomizationRow.allCases.count
        case .contact: return ContactRow.allCases.count
        case .extras: return ExtrasRow.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return section.title
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellType = CellType(indexPath: indexPath) else {
            fatalError("Invalid index path")
        }
        
        let cell: UITableViewCell
        
        switch cellType {
        case .detailViews(let row):
            let moreCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
            switch row {
            case .art:
                moreCell.configure(title: "Art", imageName: "BRCArtIcon", tag: row.rawValue)
            case .camps:
                moreCell.configure(title: "Camps", imageName: "BRCCampIcon", tag: row.rawValue)
            case .audioTour:
                moreCell.configure(title: "Audio Tour", imageName: "BRCAudioIcon", tag: row.rawValue)
            case .locationHistory:
                moreCell.configure(title: "Location History", imageName: "BRCMapIcon", tag: row.rawValue)
            }
            cell = moreCell
            
        case .customization(let row):
            let moreCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
            switch row {
            case .appearance:
                moreCell.configure(title: "Appearance", imageName: "BRCThemeIcon", tag: row.rawValue)
            }
            cell = moreCell
            
        case .contact(let row):
            let subtitleCell = tableView.dequeueReusableCell(MoreSubtitleCell.self, for: indexPath)
            switch row {
            case .feedback:
                subtitleCell.configure(title: "Report Bugs", subtitle: "Found a bug? Too bad!", imageName: "BRCMailIcon", tag: row.rawValue)
            case .share:
                subtitleCell.configure(title: "Share iBurn", subtitle: "Help spread the word!", imageName: "BRCHeart25", tag: row.rawValue)
            case .rate:
                subtitleCell.configure(title: "Rate on App Store", subtitle: "We Love You", imageName: "BRCLightStar", tag: row.rawValue)
            }
            cell = subtitleCell
            
        case .extras(let row):
            switch row {
            case .unlock:
                let unlockCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
                if BRCEmbargo.allowEmbargoedData() {
                    unlockCell.configure(title: "Location Data Unlocked", systemImageName: "lock.open.fill", tag: row.rawValue)
                    unlockCell.textLabel?.textColor = UIColor.lightGray
                    unlockCell.isUserInteractionEnabled = false
                    unlockCell.accessoryType = .none
                } else {
                    unlockCell.configure(title: "Unlock Location Data", systemImageName: "lock.fill", tag: row.rawValue)
                    unlockCell.textLabel?.textColor = Appearance.currentColors.primaryColor
                    unlockCell.isUserInteractionEnabled = true
                    unlockCell.accessoryType = .none
                }
                cell = unlockCell
            case .credits:
                let creditsCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
                creditsCell.configure(title: "Credits", imageName: "BRCCreditsIcon", tag: row.rawValue)
                cell = creditsCell
            case .debugShowOnboarding:
                let onboardingCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
                onboardingCell.configure(title: "Show Onboarding", imageName: "BRCOnboardingIcon", tag: row.rawValue)
                onboardingCell.accessoryType = .none
                cell = onboardingCell
            case .dataUpdates:
                let dataUpdatesCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
                dataUpdatesCell.configure(title: "Data Updates", systemImageName: "arrow.clockwise", tag: row.rawValue)
                cell = dataUpdatesCell
            case .navigationMode:
                let switchCell = tableView.dequeueReusableCell(MoreSwitchCell.self, for: indexPath)
                switchCell.configure(title: "Navigation Mode", subtitle: "Keep screen on when map is visible", systemImageName: "location.circle", tag: row.rawValue, switchTarget: self, switchAction: #selector(navigationModeToggled(sender:)))
                cell = switchCell
            #if DEBUG
            case .featureFlags:
                let debugCell = tableView.dequeueReusableCell(MoreTableViewCell.self, for: indexPath)
                debugCell.configure(title: "Debug", systemImageName: "ladybug", tag: row.rawValue)
                cell = debugCell
            #endif
            }
        }
        
        cell.setColorTheme(Appearance.currentColors, animated: false)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cellType = CellType(indexPath: indexPath) else { return }
        
        let cell = tableView.cellForRow(at: indexPath)
        
        switch cellType {
        case .detailViews(let row):
            switch row {
            case .art: pushArtView()
            case .camps: pushCampsView()
            case .audioTour: showAudioTour()
            case .locationHistory: pushTracksView()
            }
        case .customization(let row):
            switch row {
            case .appearance: pushAppearanceView()
            }
        case .contact(let row):
            switch row {
            case .feedback: showFeedbackView()
            case .share: showShareSheet(cell!)
            case .rate: showRatingsView()
            }
        case .extras(let row):
            switch row {
            case .unlock: showUnlockView()
            case .credits: pushCreditsView()
            case .debugShowOnboarding: showOnboardingView()
            case .dataUpdates: pushDataUpdatesView()
            case .navigationMode: break // Switch cell, no action needed
            #if DEBUG
            case .featureFlags: pushFeatureFlagsView()
            #endif
            }
        }
    }
    
    @objc func navigationModeToggled(sender: UISwitch) {
        UserDefaults.isNavigationModeDisabled = !sender.isOn
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.setColorTheme(Appearance.currentColors, animated: animated)
        refreshNavigationBarColors(animated)
        tableView.reloadData()
        
        // Update navigation mode switch state
        if let switchCell = findNavigationModeCell() {
            switchCell.isOn = !UserDefaults.isNavigationModeDisabled
        }
    }
    
    private func findNavigationModeCell() -> MoreSwitchCell? {
        let indexPath = IndexPath(row: ExtrasRow.navigationMode.rawValue, section: Section.extras.rawValue)
        return tableView.cellForRow(at: indexPath) as? MoreSwitchCell
    }
    
    func pushTracksView() {
        let tracksVC = TracksViewController()
        tracksVC.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(tracksVC, animated: true)
    }

    func pushArtView() {
        let dbManager = BRCDatabaseManager.shared
        let artVC = ObjectListViewController(viewName: dbManager.artViewName, searchViewName: dbManager.searchArtView)
        artVC.tableView.separatorStyle = .none
        artVC.title = "Art"
        navigationController?.pushViewController(artVC, animated: true)
    }

    func pushCampsView() {
        let dbManager = BRCDatabaseManager.shared
        let campsVC = ObjectListViewController(viewName: dbManager.campsViewName, searchViewName: dbManager.searchCampsView)
        campsVC.title = "Camps"
        navigationController?.pushViewController(campsVC, animated: true)
    }

    func showUnlockView() {
        let unlockVC = EmbargoPasscodeHostingViewController { [weak self] in
            self?.dismiss(animated: true, completion: nil)
            self?.tableView.reloadData()
        }
        present(unlockVC, animated: true, completion: nil)
    }

    func pushCreditsView() {
        let creditsVC = CreditsViewController()
        creditsVC.title = "Credits"
        navigationController?.pushViewController(creditsVC, animated: true)
    }

    func showFeedbackView() {
        let url = URL(string: "https://github.com/Burning-Man-Earth/iBurn-iOS/issues")!
        WebViewHelper.presentWebView(url: url, from: self)
    }

    func showShareSheet(_ fromView: UIView) {
        let url = URL(string: "http://iburnapp.com")!
        let string = "Going to Burning Man? Check out @iBurnApp for offline maps, events and more!"
        let shareVC = UIActivityViewController(activityItems: [string, url], applicationActivities: nil)
        shareVC.popoverPresentationController?.sourceView = fromView;

        present(shareVC, animated: true, completion: nil)
    }
    
    func showRatingsView() {
        let storeVC = SKStoreProductViewController()
        storeVC.delegate = self
        storeVC.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier : 388169740], completionBlock: nil)
        present(storeVC, animated: true, completion: nil)
    }
    
    // MARK: - Debug
    func pushDebugView() {
        // TODO: make debug view
    }
    
    func showOnboardingView() {
        var onboardingVC: OnboardingViewController? = nil
        onboardingVC = BRCOnboardingViewController(completion: { () -> Void in
            onboardingVC!.dismiss(animated: true, completion: nil)
        })
        onboardingVC?.modalPresentationStyle = .fullScreen
        present(onboardingVC!, animated: true, completion: nil)
    }
    
    func showAudioTour() {
        let audioTour = AudioTourViewController(style: UITableView.Style.grouped, extensionName: BRCDatabaseManager.shared.audioTourViewName)
        audioTour.title = "Audio Tour"
        navigationController?.pushViewController(audioTour, animated: true)
    }
    
    func pushAppearanceView() {
        let vc = AppearanceViewController()
        vc.title = "Appearance"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func pushDataUpdatesView() {
        let vc = DataUpdatesFactory.makeViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    #if DEBUG
    func pushFeatureFlagsView() {
        let featureFlagsVC = FeatureFlagsHostingController()
        featureFlagsVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(featureFlagsVC, animated: true)
    }
    #endif
    
    // MARK: - SKStoreProductViewControllerDelegate
    
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true, completion: nil)
    }
}

