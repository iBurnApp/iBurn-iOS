//
//  BRCSortedViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/17/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import PlayaGeocoder

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

extension CLLocation {
    static var currentLocation: CLLocation? {
        let appDelegate = BRCAppDelegate.shared
        let currentLocation = appDelegate.locationManager.location
        return currentLocation
    }
}

extension UIViewController {
    /** Adds current geocoded playa address to navigation bar title */
    func geocodeNavigationBar() {
        guard let location = CLLocation.currentLocation else { return }
        PlayaGeocoder.shared.asyncReverseLookup(location.coordinate) { locationString in
            if let locationString = locationString, locationString.count > 0 {
                let attrString = (locationString as NSString).brc_attributedLocationStringWithCrosshairs
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


@objc(BRCSortedViewController)
public class SortedViewController: UITableViewController {

    var sections: [TableViewSection] = []
    var extensionRegistered: Bool = false
    var extensionName: String = ""
    var emptyListText = EmptyListLabelText.Loading
    var emptyDetailText: String = ""
    private lazy var pageViewManager: PageViewManager = {
        let pvm = PageViewManager(objectProvider: self, tableView: tableView)
        return pvm
    }()
    private var geocoderTimer: Timer? {
        didSet {
            oldValue?.invalidate()
            geocoderTimer?.tolerance = 1
        }
    }
    
    deinit {
        geocoderTimer?.invalidate()
    }
    
    public override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    @objc public required init(style: UITableView.Style, extensionName ext: String) {
        super.init(style: style)
        extensionName = ext
        BRCDatabaseManager.shared.uiConnection.read { (transaction: YapDatabaseReadTransaction) -> Void in
            let ext: AnyObject? = transaction.ext(self.extensionName)
            if (ext != nil) {
                self.extensionRegistered = true
            }
        }
        NotificationCenter.default.addObserver(self, selector: NSSelectorFromString("databaseExtensionRegistered:"), name: NSNotification.Name.BRCDatabaseExtensionRegistered, object: BRCDatabaseManager.shared);
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
        tableView.rowHeight = UITableView.automaticDimension
        // register table cell classes
        tableView.registerCustomCellClasses()
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.kReuseIdentifier)
    }
    
    @objc func databaseExtensionRegistered(_ notification: Notification) {
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
    
    @objc open func audioPlayerChangeNotification(_ notification: Notification) {
        self.tableView.reloadData()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNavigationBarColors(animated)
        refreshTableItems { () -> Void in
            self.tableView.reloadData();
        }
        geocodeNavigationBar()
        geocoderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.geocodeNavigationBar()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        geocoderTimer = nil
    }
    
    
    // MARK: - Internal
    
    func getCurrentLocation() -> CLLocation? {
        let appDelegate = BRCAppDelegate.shared
        let currentLocation: CLLocation? = appDelegate.locationManager.location
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
        return UITableView.automaticDimension
    }
    
    override open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    override open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !hasTableItems() {
            return 55
        }
        return UITableView.automaticDimension
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
        guard let dataObject = dataObjectAtIndexPath(indexPath) else {
            return UITableViewCell()
        }
        let cell = BRCDataObjectTableViewCell.cell(at: indexPath, tableView: tableView, dataObject: dataObject, writeConnection: BRCDatabaseManager.shared.readWriteConnection)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !hasTableItems() {
            return
        }
        guard let data = dataObjectAtIndexPath(indexPath) else {
            return
        }
        let pageVC = pageViewManager.pageViewController(for: data.object, at: indexPath, navBar: self.navigationController?.navigationBar)
        navigationController?.pushViewController(pageVC, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SortedViewController: DataObjectProvider {
    public func dataObjectAtIndexPath(_ indexPath: IndexPath) -> DataObject? {
        let object = sections[indexPath.section].objects[indexPath.row]
        var metadata: BRCObjectMetadata? = nil
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            metadata = object.metadata(with: transaction)
        }
        guard let objectMetadata = metadata else {
            return nil
        }
        let dataObject = DataObject(object: object, metadata: objectMetadata)
        return dataObject
    }
}
