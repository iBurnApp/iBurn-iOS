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

open class TableViewSection {
    let objects: [BRCDataObject]
    let sectionTitle: ObjectType
    public init(objects: [BRCDataObject], sectionTitle: ObjectType) {
        self.objects = objects
        self.sectionTitle = sectionTitle
    }
}

open class BRCSortedViewController: UITableViewController {

    var sections: [TableViewSection] = []
    var extensionRegistered: Bool = false
    var extensionName: String = ""
    var emptyListText = EmptyListLabelText.Loading
    var emptyDetailText: String = ""
    
    public override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    public required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style)
        extensionName = ext
        BRCDatabaseManager.sharedInstance().readConnection.read { (transaction: YapDatabaseReadTransaction) -> Void in
            let ext: AnyObject? = transaction.ext(self.extensionName)
            if (ext != nil) {
                self.extensionRegistered = true
            }
        }
        NotificationCenter.default.addObserver(self, selector: NSSelectorFromString("databaseExtensionRegistered:"), name: NSNotification.Name.BRCDatabaseExtensionRegistered, object: BRCDatabaseManager.sharedInstance());
        NotificationCenter.default.addObserver(self, selector: #selector(audioPlayerChangeNotification(_:)), name: NSNotification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification), object: BRCAudioPlayer.sharedInstance)
    }
    
    fileprivate override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - View cycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        // Apple bug: https://github.com/smileyborg/TableViewCellWithAutoLayoutiOS8/issues/10#issuecomment-69694089
        self.tableView.reloadData()
        self.tableView.setNeedsLayout()
        self.tableView.layoutIfNeeded()
        self.tableView.reloadData()
    }
    
    func setupTableView() {
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
        // register table cell classes
        let classesToRegister = [BRCEventObject.self, BRCDataObject.self, BRCArtObject.self]
        for objClass in classesToRegister {
            let cellClass: (AnyClass!) = BRCDataObjectTableViewCell.cellClass(forDataObjectClass: objClass)
            let nib = UINib(nibName: NSStringFromClass(cellClass), bundle: nil)
            let reuseIdentifier = cellClass.cellIdentifier()
            tableView.register(nib, forCellReuseIdentifier: reuseIdentifier!)
        }
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.kReuseIdentifier)
    }
    
    func databaseExtensionRegistered(_ notification: Notification) {
        if let extensionName = notification.userInfo?["extensionName"] as? String {
            if extensionName == self.extensionName {
                NSLog("databaseExtensionRegistered: %@", extensionName)
                extensionRegistered = true
                refreshTableItems({ () -> Void in
                    self.tableView.reloadData()
                })
            }
        }
    }
    
    open func audioPlayerChangeNotification(_ notification: Notification) {
        self.tableView.reloadData()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let title = self.title {
            PFAnalytics.trackEvent(inBackground: title, block: nil)
        }
        
        refreshTableItems { () -> Void in
            self.tableView.reloadData();
        }
        if let location = getCurrentLocation() {
            BRCGeocoder.sharedInstance().asyncReverseLookup(location.coordinate, completionQueue: DispatchQueue.main) { (locationString: String!) -> Void in
                if locationString.characters.count > 0 {
                    let attrString = BRCGeocoder.locationString(withCrosshairs: locationString)
                    let label = UILabel()
                    label.attributedText = attrString
                    label.sizeToFit()
                    self.navigationItem.titleView = label
                } else {
                    self.navigationItem.title = self.title
                }
            }
        }
    }
    
    
    // MARK: - Internal
    
    func getCurrentLocation() -> CLLocation? {
        let appDelegate = BRCAppDelegate.shared()
        let currentLocation: CLLocation? = appDelegate?.locationManager.location
        return currentLocation
    }
    
    func refreshTableItems(_ completion: @escaping ()->()) {
        preconditionFailure("This method must be overridden")
    }
    
    /** processes results of BRCDataSorter */
    func processSortedData(_ events: [BRCEventObject], art: [BRCArtObject], camps: [BRCCampObject], completion: ()->()) {
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
        if sections.count == 0 && self.extensionRegistered {
            self.emptyListText = EmptyListLabelText.Nothing
        }
        completion()
    }
    
    func hasTableItems() -> Bool {
        if sections.count > 0 {
            return true
        }
        return false
    }
    
    // MARK: - Table view data source
    
    override open func numberOfSections(in tableView: UITableView) -> Int {
        if !hasTableItems() {
            return 1
        }
        return sections.count
    }
    
    override open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !hasTableItems() {
            return 1
        }
        return sections[section].objects.count
    }
    
    override open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !hasTableItems() {
            return nil
        }
        return sections[section].sectionTitle.rawValue
    }
    
    override open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !hasTableItems() {
            return 0
        }
        return UITableViewAutomaticDimension
    }
    
    override open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    override open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !hasTableItems() {
            return 55
        }
        return UITableViewAutomaticDimension
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !hasTableItems() {
            let cell = tableView.dequeueReusableCell(withIdentifier: SubtitleCell.kReuseIdentifier, for: indexPath) as! SubtitleCell
            cell.textLabel!.text = emptyListText.rawValue
            switch emptyListText {
            case EmptyListLabelText.Nothing:
                cell.detailTextLabel!.text = emptyDetailText
            case EmptyListLabelText.Loading:
                cell.detailTextLabel!.text = nil
            }
            return cell
        }
        
        let dataObject = sections[indexPath.section].objects[indexPath.row]
        
        let dataObjectClass = type(of: dataObject)
        let cellClass: (AnyClass!) = BRCDataObjectTableViewCell.cellClass(forDataObjectClass: dataObjectClass)
        let reuseIdentifier = cellClass.cellIdentifier()
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier!, for: indexPath) as! BRCDataObjectTableViewCell
        cell.setDataObject(dataObject)
        cell.updateDistanceLabel(from: getCurrentLocation(), dataObject: dataObject)
        cell.favoriteButtonAction = { (sender) -> Void in
            let dataCopy = dataObject.copy() as! BRCDataObject
            dataCopy.isFavorite = cell.favoriteButton.isSelected
            BRCDatabaseManager.sharedInstance().readWriteConnection!.asyncReadWrite({ (transaction: YapDatabaseReadWriteTransaction) -> Void in
                transaction.setObject(dataCopy, forKey: dataCopy.uniqueID, inCollection: type(of: dataCopy).collection())
                if let event = dataCopy as? BRCEventObject {
                    event.refreshCalendarEntry(transaction)
                }
                }, completionQueue:DispatchQueue.main, completionBlock: { () -> Void in
                    self.refreshTableItems({ () -> Void in
                        self.tableView.reloadData()
                    })
            })
        }
        if let artCell = cell as? BRCArtObjectTableViewCell {
            artCell.configurePlayPauseButton(dataObject as! BRCArtObject)
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !hasTableItems() {
            return
        }
        let dataObject = sections[indexPath.section].objects[indexPath.row]
        let detailVC = BRCDetailViewController(dataObject: dataObject)
        detailVC.hidesBottomBarWhenPushed = true
        navigationController!.pushViewController(detailVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
