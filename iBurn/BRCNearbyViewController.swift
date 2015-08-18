//
//  BRCNearbyViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import MapKit
import Parse
import PureLayout
import YapDatabase

private enum EmptyListLabelText: String {
    case Loading = "Loading...",
    Nothing = "Nothing Nearby"
}

private enum ObjectType: String {
    case Events = "Events",
    Camps = "Camps",
    Art = "Art"
}

private class TableViewSection {
    let objects: [BRCDataObject]
    let sectionTitle: ObjectType
    private init(objects: [BRCDataObject], sectionTitle: ObjectType) {
        self.objects = objects
        self.sectionTitle = sectionTitle
    }
}

class BRCNearbyViewController: UITableViewController {

    private var sections: [TableViewSection] = []
    private var extensionRegistered: Bool = false
    
    private var emptyListText = EmptyListLabelText.Loading
    private var searchDistance: CLLocationDistance = 500
    
    let tableHeaderLabel: UILabel = UILabel()
    let distanceStepper: UIStepper = UIStepper()
    let tableHeaderView: UIView = UIView()
    
    // MARK: - View cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        BRCDatabaseManager.sharedInstance().readConnection.readWithBlock { (transaction: YapDatabaseReadTransaction) -> Void in
            let extName = BRCDatabaseManager.sharedInstance().rTreeIndex
            let ext: AnyObject? = transaction.ext(extName)
            if (ext != nil) {
                self.extensionRegistered = true
            }
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: NSSelectorFromString("databaseExtensionRegistered:"), name: BRCDatabaseExtensionRegisteredNotification, object: BRCDatabaseManager.sharedInstance());
    }
    
    func databaseExtensionRegistered(notification: NSNotification) {
        if let extensionName = notification.userInfo?["extensionName"] as? String {
            if extensionName == BRCDatabaseManager.sharedInstance().rTreeIndex {
                extensionRegistered = true
                refreshNearbyItems()
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        PFAnalytics.trackEventInBackground("Nearby", block: nil)
        refreshTableHeaderView()
        refreshNearbyItems()
        let location = BRCAppDelegate.sharedAppDelegate().locationManager.location
        BRCGeocoder.sharedInstance().asyncReverseLookup(location.coordinate, completionQueue: dispatch_get_main_queue()) { (locationString: String!) -> Void in
            if count(locationString) > 0 {
                let attrString = BRCGeocoder.locationStringWithCrosshairs(locationString)
                let label = UILabel()
                label.attributedText = attrString
                label.sizeToFit()
                self.navigationItem.titleView = label
            } else {
                self.navigationItem.title = self.title
            }
        }
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
    
    // MARK: - Internal
    
    func getCurrentLocation() -> CLLocation {
        let appDelegate = BRCAppDelegate.sharedAppDelegate()
        let currentLocation = appDelegate.locationManager.location
        return currentLocation
    }
    
    func refreshNearbyItems() {
        let currentLocation = getCurrentLocation()
        let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, searchDistance, searchDistance)
        emptyListText = EmptyListLabelText.Loading
        BRCDatabaseManager.sharedInstance().queryObjectsInRegion(region, completionQueue: dispatch_get_main_queue(), resultsBlock: { (results: [AnyObject]!) -> Void in
            let nearbyObjects = results as! [BRCDataObject]
            let options = BRCDataSorterOptions()
            BRCDataSorter.sortDataObjects(nearbyObjects, options: options, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
                var sections: [TableViewSection] = []
                if events.count > 0 {
                    let eventsSection = TableViewSection(objects: events, sectionTitle: ObjectType.Events)
                    sections.append(eventsSection)
                }
                if art.count > 0 {
                    let artSection = TableViewSection(objects: art, sectionTitle: ObjectType.Art)
                    sections.append(artSection)
                }
                if camps.count > 0 {
                    let campsSection = TableViewSection(objects: camps, sectionTitle: ObjectType.Camps)
                    sections.append(campsSection)
                }
                self.sections = sections
                if count(sections) == 0 && self.extensionRegistered {
                    self.emptyListText = EmptyListLabelText.Nothing
                }
                self.tableView.reloadData()
            })
        })
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
    
    func setupTableView() {
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
        setupTableHeaderView()
        // register table cell classes
        let classesToRegister = [BRCEventObject.self, BRCDataObject.self]
        for objClass in classesToRegister {
            let cellClass: (AnyClass!) = BRCDataObjectTableViewCell.cellClassForDataObjectClass(objClass)
            let nib = UINib(nibName: NSStringFromClass(cellClass), bundle: nil)
            let reuseIdentifier = cellClass.cellIdentifier()
            tableView.registerNib(nib, forCellReuseIdentifier: reuseIdentifier)
        }
        tableView.registerClass(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.kReuseIdentifier)
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
            refreshNearbyItems()
        }
    }

    
    private func hasNearbyObjects() -> Bool {
        if sections.count > 0 {
            return true
        }
        return false
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if !hasNearbyObjects() {
            return 1
        }
        return sections.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !hasNearbyObjects() {
            return 1
        }
        return sections[section].objects.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !hasNearbyObjects() {
            return nil
        }
        return sections[section].sectionTitle.rawValue
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !hasNearbyObjects() {
            return 0
        }
        return 25
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if !hasNearbyObjects() {
            return 55
        }
        return UITableViewAutomaticDimension
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if !hasNearbyObjects() {
            let cell = tableView.dequeueReusableCellWithIdentifier(SubtitleCell.kReuseIdentifier, forIndexPath: indexPath) as! SubtitleCell
            cell.textLabel!.text = emptyListText.rawValue
            switch emptyListText {
            case EmptyListLabelText.Nothing:
                cell.detailTextLabel!.text = "Check back when you're at Burning Man!"
            case EmptyListLabelText.Loading:
                cell.detailTextLabel!.text = nil
            }
            return cell
        }
        
        let dataObject = sections[indexPath.section].objects[indexPath.row]
        
        let dataObjectClass = dataObject.dynamicType
        let cellClass: (AnyClass!) = BRCDataObjectTableViewCell.cellClassForDataObjectClass(dataObjectClass)
        let reuseIdentifier = cellClass.cellIdentifier()
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! BRCDataObjectTableViewCell
        cell.dataObject = dataObject
        cell.updateDistanceLabelFromLocation(getCurrentLocation())
        cell.favoriteButtonAction = { () -> Void in
            let dataCopy = dataObject.copy() as! BRCDataObject
            dataCopy.isFavorite = cell.favoriteButton.selected
            BRCDatabaseManager.sharedInstance().readWriteConnection!.asyncReadWriteWithBlock({ (transaction: YapDatabaseReadWriteTransaction) -> Void in
                transaction.setObject(dataCopy, forKey: dataCopy.uniqueID, inCollection: dataCopy.dynamicType.collection())
            }, completionQueue:dispatch_get_main_queue(), completionBlock: { () -> Void in
                self.refreshNearbyItems()
            })
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if !hasNearbyObjects() {
            return
        }
        let dataObject = sections[indexPath.section].objects[indexPath.row]
        let detailVC = BRCDetailViewController(dataObject: dataObject)
        detailVC.hidesBottomBarWhenPushed = true
        navigationController!.pushViewController(detailVC, animated: true)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
}
