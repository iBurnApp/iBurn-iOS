//
//  BRCSortedViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/17/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import Parse

public enum EmptyListLabelText: String {
    case Loading = "Loading...",
    Nothing = "Nothing Here"
}

public enum ObjectType: String {
    case Events = "Events",
    Camps = "Camps",
    Art = "Art"
}

public class TableViewSection {
    let objects: [BRCDataObject]
    let sectionTitle: ObjectType
    public init(objects: [BRCDataObject], sectionTitle: ObjectType) {
        self.objects = objects
        self.sectionTitle = sectionTitle
    }
}

public class BRCSortedViewController: UITableViewController {

    var sections: [TableViewSection] = []
    var extensionRegistered: Bool = false
    var extensionName: String = ""
    var emptyListText = EmptyListLabelText.Loading
    
    public override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    public required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style)
        extensionName = ext
        BRCDatabaseManager.sharedInstance().readConnection.readWithBlock { (transaction: YapDatabaseReadTransaction) -> Void in
            let ext: AnyObject? = transaction.ext(self.extensionName)
            if (ext != nil) {
                self.extensionRegistered = true
            }
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: NSSelectorFromString("databaseExtensionRegistered:"), name: BRCDatabaseExtensionRegisteredNotification, object: BRCDatabaseManager.sharedInstance());
    }
    
    private override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - View cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    func setupTableView() {
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
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
    
    func databaseExtensionRegistered(notification: NSNotification) {
        if let extensionName = notification.userInfo?["extensionName"] as? String {
            if extensionName == self.extensionName {
                NSLog("databaseExtensionRegistered: %@", extensionName)
                extensionRegistered = true
                refreshTableItems()
            }
        }
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if let title = self.title {
            PFAnalytics.trackEventInBackground(title, block: nil)
        }
        refreshTableItems()
        let location = getCurrentLocation()
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
    
    
    // MARK: - Internal
    
    func getCurrentLocation() -> CLLocation {
        let appDelegate = BRCAppDelegate.sharedAppDelegate()
        let currentLocation = appDelegate.locationManager.location
        return currentLocation
    }
    
    func refreshTableItems() {
        preconditionFailure("This method must be overridden")
    }
    
    /** processes results of BRCDataSorter */
    func processSortedData(events: [BRCEventObject], art: [BRCArtObject], camps: [BRCCampObject]) {
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
    }
    
    func hasTableItems() -> Bool {
        if sections.count > 0 {
            return true
        }
        return false
    }
    
    // MARK: - Table view data source
    
    override public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if !hasTableItems() {
            return 1
        }
        return sections.count
    }
    
    override public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !hasTableItems() {
            return 1
        }
        return sections[section].objects.count
    }
    
    override public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !hasTableItems() {
            return nil
        }
        return sections[section].sectionTitle.rawValue
    }
    
    override public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !hasTableItems() {
            return 0
        }
        return UITableViewAutomaticDimension
    }
    
    override public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    override public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if !hasTableItems() {
            return 55
        }
        return UITableViewAutomaticDimension
    }
    
    override public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if !hasTableItems() {
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
                    self.refreshTableItems()
            })
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if !hasTableItems() {
            return
        }
        let dataObject = sections[indexPath.section].objects[indexPath.row]
        let detailVC = BRCDetailViewController(dataObject: dataObject)
        detailVC.hidesBottomBarWhenPushed = true
        navigationController!.pushViewController(detailVC, animated: true)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
