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
    
    private let navigationModeSwitch = UISwitch()
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
        navigationModeSwitch.addTarget(self, action: #selector(navigationModeToggled(sender:)), for: .valueChanged)
        self.tableView.tableFooterView = versionLabel
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.setColorTheme(Appearance.currentColors, animated: animated)
        refreshNavigationBarColors(animated)
        tableView.reloadData()
        navigationModeSwitch.isOn = !UserDefaults.isNavigationModeDisabled
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITableViewDelegate & DataSource
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        cell.setColorTheme(Appearance.currentColors, animated: false)
        
        if let cellImage = cell.imageView?.image {
            cell.imageView!.image = cellImage.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        }
        
        switch CellTag(rawValue: cell.tag) {
        case .unlock:
            if BRCEmbargo.allowEmbargoedData() {
                cell.imageView!.image = UIImage(systemName: "lock.open.fill")
                cell.textLabel!.text = "Location Data Unlocked"
                cell.textLabel!.textColor = UIColor.lightGray
                cell.isUserInteractionEnabled = false
            } else {
                cell.imageView!.image = UIImage(systemName: "lock.fill")
                cell.textLabel!.text = "Unlock Location Data"
                cell.textLabel!.textColor = Appearance.currentColors.primaryColor
                cell.isUserInteractionEnabled = true
            }
        case .navigationMode:
            cell.accessoryView = navigationModeSwitch
            cell.selectionStyle = .none
        default:
            cell.accessoryView = nil
            cell.selectionStyle = .default
        }
        
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
        let vc = AppearanceViewController.fromStoryboard()
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

extension MoreViewController: StoryboardRepresentable {
    static func fromStoryboard() -> UIViewController {
        return Storyboard.more.instantiateInitialViewController()!
    }
}
