//
//  MoreViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/13/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import StoreKit


class MoreViewController: UITableViewController, SKStoreProductViewControllerDelegate {
    
    enum CellTag: Int {
        case art = 1,
        camps = 2,
        unlock = 3,
        credits = 4,
        feedback = 5,
        share = 6,
        rate = 7,
        debugShowOnboarding = 8,
        audioTour = 9,
        appearance = 10,
        locationHistory = 11
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "More"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.setColorTheme(Appearance.currentColors, animated: animated)
        refreshNavigationBarColors(animated)
        tableView.reloadData()
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
        
        if cell.tag == CellTag.unlock.rawValue {
            if BRCEmbargo.allowEmbargoedData() {
                cell.imageView!.image = UIImage(named: "BRCUnlockIcon")!.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
                cell.textLabel!.text = "Location Data Unlocked"
                cell.textLabel!.textColor = UIColor.lightGray
                cell.isUserInteractionEnabled = false
            }
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
        }
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
        let unlockVC = BRCEmbargoPasscodeViewController()
        unlockVC.dismissAction = {
            unlockVC.dismiss(animated: true, completion: nil)
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

