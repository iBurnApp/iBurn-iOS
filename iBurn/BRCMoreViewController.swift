//
//  BRCMoreViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/13/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import HockeySDK_Source
import StoreKit

enum CellTag: Int {
    case Art = 1,
    Camps,
    Unlock,
    Credits,
    Feedback,
    Share,
    Rate,
    DebugShowOnboarding
}

class BRCMoreViewController: UITableViewController, SKStoreProductViewControllerDelegate {
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "More"
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UITableViewDelegate & DataSource
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        
        if let cellImage = cell.imageView?.image {
            cell.imageView!.image = cellImage.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
        }
        
        if cell.tag == CellTag.Unlock.rawValue {
            if BRCEmbargo.allowEmbargoedData() {
                cell.imageView!.image = UIImage(named: "BRCUnlockIcon")!.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                cell.textLabel!.text = "Location Data Unlocked"
                cell.textLabel!.textColor = UIColor.lightGrayColor()
                cell.userInteractionEnabled = false
            }
        }

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let cell = tableView.cellForRowAtIndexPath(indexPath)!
        let cellTag = CellTag(rawValue: cell.tag)!
        
        switch cellTag {
        case .Art:
            pushArtView()
        case .Camps:
            pushCampsView()
        case .Unlock:
            showUnlockView()
        case .Credits:
            pushCreditsView()
        case .Feedback:
            showFeedbackView()
        case .Share:
            showShareSheet()
        case .Rate:
            showRatingsView()
        case .DebugShowOnboarding:
            showOnboardingView()
        }
    }

    func pushArtView() {
        let dbManager = BRCDatabaseManager.sharedInstance()
        let artVC = BRCFilteredTableViewController(viewClass: BRCArtObject.self, viewName: dbManager.artViewName, searchViewName: dbManager.searchArtView)
        artVC.title = "Art"
        artVC.hidesBottomBarWhenPushed = true
        navigationController!.pushViewController(artVC, animated: true)
    }

    func pushCampsView() {
        let dbManager = BRCDatabaseManager.sharedInstance()
        let campsVC = BRCFilteredTableViewController(viewClass: BRCCampObject.self, viewName: dbManager.campsViewName, searchViewName: dbManager.searchCampsView)
        campsVC.title = "Camps"
        campsVC.hidesBottomBarWhenPushed = true
        navigationController!.pushViewController(campsVC, animated: true)
    }

    func showUnlockView() {
        let unlockVC = BRCEmbargoPasscodeViewController()
        unlockVC.dismissAction = {
            unlockVC.dismissViewControllerAnimated(true, completion: nil)
        }
        presentViewController(unlockVC, animated: true, completion: nil)
    }

    func pushCreditsView() {
        let creditsVC = BRCCreditsViewController()
        creditsVC.title = "Credits"
        creditsVC.hidesBottomBarWhenPushed = true
        navigationController!.pushViewController(creditsVC, animated: true)
    }

    func showFeedbackView() {
        BITHockeyManager.sharedHockeyManager().feedbackManager.showFeedbackListView()
    }

    func showShareSheet() {
        let url = NSURL(string: "http://iburnapp.com")!
        let string = "Going to Burning Man? Check out @iBurnApp for offline maps, events and more!"
        let shareVC = UIActivityViewController(activityItems: [string, url], applicationActivities: nil)
        presentViewController(shareVC, animated: true, completion: nil)
    }
    
    func showRatingsView() {
        let storeVC = SKStoreProductViewController()
        storeVC.delegate = self
        storeVC.loadProductWithParameters([SKStoreProductParameterITunesItemIdentifier : 388169740], completionBlock: nil)
        presentViewController(storeVC, animated: true, completion: nil)
    }
    
    // MARK: - Debug
    func pushDebugView() {
        // TODO: make debug view
    }
    
    func showOnboardingView() {
        var onboardingVC: OnboardingViewController? = nil
        onboardingVC = BRCAppDelegate.onboardingViewControllerWithCompletion { () -> Void in
            onboardingVC!.dismissViewControllerAnimated(true, completion: nil)
        }
        presentViewController(onboardingVC!, animated: true, completion: nil)
    }
    
    // MARK: - SKStoreProductViewControllerDelegate
    
    func productViewControllerDidFinish(viewController: SKStoreProductViewController!) {
        viewController.dismissViewControllerAnimated(true, completion: nil)
    }

}
