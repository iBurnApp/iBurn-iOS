//
//  BRCNearbyViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import MapKit
import PureLayout

class BRCNearbyViewController: BRCSortedViewController {

    private var searchDistance: CLLocationDistance = 500
    
    let tableHeaderLabel: UILabel = UILabel()
    let distanceStepper: UIStepper = UIStepper()
    let tableHeaderView: UIView = UIView()
    
    required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style, extensionName: ext)
        emptyDetailText = "Try a bigger search area."
    }
    
    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }
    
    
    // MARK: - View cycle
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        refreshTableHeaderView()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        coordinator.animateAlongsideTransition({ (_) -> Void in
            self.refreshTableHeaderView()
        }, completion:nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    internal override func refreshTableItems(completion: dispatch_block_t) {
        if let currentLocation = getCurrentLocation() {
            let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, searchDistance, searchDistance)
            emptyListText = EmptyListLabelText.Loading
            BRCDatabaseManager.sharedInstance().queryObjectsInRegion(region, completionQueue: dispatch_get_main_queue(), resultsBlock: { (results: [AnyObject]!) -> Void in
                let nearbyObjects = results as! [BRCDataObject]
                let options = BRCDataSorterOptions()
                BRCDataSorter.sortDataObjects(nearbyObjects, options: options, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
                    self.processSortedData(events, art: art, camps: camps, completion: completion)
                })
            })
        }
    }
    
    func refreshHeaderLabel() {
        let labelText: NSMutableAttributedString = NSMutableAttributedString()
        let font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        let attributes: [String: AnyObject] = [NSFontAttributeName: font]
        labelText.appendAttributedString(NSAttributedString(string: "Within ", attributes: attributes))
        labelText.appendAttributedString(TTTLocationFormatter.brc_humanizedStringForDistance(searchDistance))
        tableHeaderLabel.attributedText = labelText
        tableHeaderLabel.sizeToFit()
    }
    
    func refreshTableHeaderView() {
        refreshHeaderLabel()
        tableHeaderView.frame = CGRectMake(0, 0, self.view.frame.size.width, 45)
        tableView.tableHeaderView = tableHeaderView
    }
    
    override func setupTableView() {
        super.setupTableView()
        setupTableHeaderView()
    }
    
    func setupTableHeaderView() {
        tableHeaderLabel.textAlignment = NSTextAlignment.Left
        tableHeaderLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        distanceStepper.setTranslatesAutoresizingMaskIntoConstraints(false)
        setupDistanceStepper()
        tableHeaderView.addSubview(tableHeaderLabel)
        tableHeaderView.addSubview(distanceStepper)
        tableHeaderLabel.autoAlignAxis(ALAxis.Horizontal, toSameAxisOfView: distanceStepper)
        tableHeaderLabel.autoPinEdge(ALEdge.Right, toEdge: ALEdge.Left, ofView: distanceStepper)
        tableHeaderLabel.autoPinEdgeToSuperviewMargin(ALEdge.Left)
        distanceStepper.autoAlignAxisToSuperviewMarginAxis(ALAxis.Horizontal)
        distanceStepper.autoPinEdgeToSuperviewMargin(ALEdge.Right)
        tableHeaderView.setTranslatesAutoresizingMaskIntoConstraints(true)
        tableHeaderView.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth
        refreshTableHeaderView()
    }
    
    func setupDistanceStepper() {
        // units in CLLocationDistance (meters)
        distanceStepper.minimumValue = 50
        distanceStepper.maximumValue = 3200 // approx 2 miles
        distanceStepper.value = searchDistance
        distanceStepper.stepValue = 150
        distanceStepper.addTarget(self, action: Selector("stepperValueChanged:"), forControlEvents: UIControlEvents.ValueChanged)
    }
    
    func stepperValueChanged(sender: AnyObject?) {
        if let stepper = sender as? UIStepper {
            searchDistance = stepper.value
            refreshTableHeaderView()
            refreshTableItems({ () -> Void in
                self.tableView.reloadData()
            })
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !hasTableItems() {
            return 0
        }
        if section == 0 {
            return 25
        }
        return UITableViewAutomaticDimension
    }

}
