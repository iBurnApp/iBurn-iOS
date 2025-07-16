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

class MoreViewController: UITableViewController, SKStoreProductViewControllerDelegate {
    
    // MARK: - Initialization
    
    init() {
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    enum CellTag: Int {
        case art = 1
        case camps = 2
        case unlock = 3
        case credits = 4
        case feedback = 5
        case share = 6
        case rate = 7
        case debugShowOnboarding = 8
        case audioTour = 9
        case appearance = 10
        case locationHistory = 11
        case navigationMode = 12
        case dataUpdates = 13
        #if DEBUG
        case featureFlags = 14
        #endif
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
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 4  // Detail Views: Art, Camps, Audio Tour, Location History
        case 1: return 1  // Customization: Appearance
        case 2: return 3  // Contact: Report Bugs, Share, Rate
        case 3:
            #if DEBUG
            return 6  // Extras: Unlock, Credits, Show Onboarding, Data Updates, Navigation Mode, Debug
            #else
            return 5  // Extras: Unlock, Credits, Show Onboarding, Data Updates, Navigation Mode
            #endif
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 3 ? "Extras" : nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0): // Art
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Art", imageName: "BRCArtIcon", tag: CellTag.art.rawValue)
            
        case (0, 1): // Camps
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Camps", imageName: "BRCCampIcon", tag: CellTag.camps.rawValue)
            
        case (0, 2): // Audio Tour
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Audio Tour", imageName: "BRCAudioIcon", tag: CellTag.audioTour.rawValue)
            
        case (0, 3): // Location History
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Location History", imageName: "BRCMapIcon", tag: CellTag.locationHistory.rawValue)
            
        case (1, 0): // Appearance
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Appearance", imageName: "BRCThemeIcon", tag: CellTag.appearance.rawValue)
            
        case (2, 0): // Report Bugs
            cell = tableView.dequeueReusableCell(withIdentifier: MoreSubtitleCell.reuseIdentifier, for: indexPath)
            (cell as! MoreSubtitleCell).configure(title: "Report Bugs", subtitle: "Found a bug? Too bad!", imageName: "BRCMailIcon", tag: CellTag.feedback.rawValue)
            
        case (2, 1): // Share
            cell = tableView.dequeueReusableCell(withIdentifier: MoreSubtitleCell.reuseIdentifier, for: indexPath)
            (cell as! MoreSubtitleCell).configure(title: "Share iBurn", subtitle: "Help spread the word!", imageName: "BRCHeart25", tag: CellTag.share.rawValue)
            
        case (2, 2): // Rate
            cell = tableView.dequeueReusableCell(withIdentifier: MoreSubtitleCell.reuseIdentifier, for: indexPath)
            (cell as! MoreSubtitleCell).configure(title: "Rate on App Store", subtitle: "We Love You", imageName: "BRCLightStar", tag: CellTag.rate.rawValue)
            
        case (3, 0): // Unlock Location Data
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            let unlockCell = cell as! MoreTableViewCell
            if BRCEmbargo.allowEmbargoedData() {
                unlockCell.configure(title: "Location Data Unlocked", systemImageName: "lock.open.fill", tag: CellTag.unlock.rawValue)
                unlockCell.textLabel?.textColor = UIColor.lightGray
                unlockCell.isUserInteractionEnabled = false
                unlockCell.accessoryType = .none
            } else {
                unlockCell.configure(title: "Unlock Location Data", systemImageName: "lock.fill", tag: CellTag.unlock.rawValue)
                unlockCell.textLabel?.textColor = Appearance.currentColors.primaryColor
                unlockCell.isUserInteractionEnabled = true
                unlockCell.accessoryType = .none
            }
            
        case (3, 1): // Credits
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Credits", imageName: "BRCCreditsIcon", tag: CellTag.credits.rawValue)
            
        case (3, 2): // Show Onboarding
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            let onboardingCell = cell as! MoreTableViewCell
            onboardingCell.configure(title: "Show Onboarding", imageName: "BRCOnboardingIcon", tag: CellTag.debugShowOnboarding.rawValue)
            onboardingCell.accessoryType = .none
            
        case (3, 3): // Data Updates
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Data Updates", systemImageName: "arrow.clockwise", tag: CellTag.dataUpdates.rawValue)
            
        case (3, 4): // Navigation Mode
            cell = tableView.dequeueReusableCell(withIdentifier: MoreSwitchCell.reuseIdentifier, for: indexPath)
            (cell as! MoreSwitchCell).configure(title: "Navigation Mode", subtitle: "Keep screen on when map is visible", systemImageName: "location.circle", tag: CellTag.navigationMode.rawValue, switchTarget: self, switchAction: #selector(navigationModeToggled(sender:)))
            
        case (3, 5): // Debug (DEBUG only)
            #if DEBUG
            cell = tableView.dequeueReusableCell(withIdentifier: MoreTableViewCell.reuseIdentifier, for: indexPath)
            (cell as! MoreTableViewCell).configure(title: "Debug", systemImageName: "ladybug", tag: CellTag.featureFlags.rawValue)
            #else
            fatalError("Invalid index path")
            #endif
            
        default:
            fatalError("Invalid index path")
        }
        
        cell.setColorTheme(Appearance.currentColors, animated: false)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath),
        let cellTag = CellTag(rawValue: cell.tag) else {
            return
        }
        switch cellTag {
        case .art:
            pushArtView()
        case .camps:
            pushCampsView()
        case .unlock:
            showUnlockView()
        case .credits:
            pushCreditsView()
        case .feedback:
            showFeedbackView()
        case .share:
            showShareSheet(cell)
        case .rate:
            showRatingsView()
        case .debugShowOnboarding:
            showOnboardingView()
        case .audioTour:
            showAudioTour()
        case .appearance:
            pushAppearanceView()
        case .locationHistory:
            pushTracksView()
        case .navigationMode:
            break
        case .dataUpdates:
            pushDataUpdatesView()
        #if DEBUG
        case .featureFlags:
            pushFeatureFlagsView()
        #endif
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
        let indexPath = IndexPath(row: 4, section: 3)
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
        }
        unlockVC.modalPresentationStyle = .fullScreen
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

