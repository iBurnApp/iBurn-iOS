//
//  BRCNearbyViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import MapKit

private enum TableSection: Int {
    case Events = 0,
    Camps,
    Art
}

private enum EmptyListLabelText: String {
    case Loading = "Loading...",
    Nothing = "Nothing Nearby"
}

class BRCNearbyViewController: UITableViewController {

    var nearbyEvents: [BRCEventObject] = []
    var nearbyCamps: [BRCCampObject] = []
    var nearbyArt: [BRCArtObject] = []
    
    private var emptyListText = EmptyListLabelText.Loading
    
    // MARK - View cycle 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.estimatedRowHeight = 120
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        // register table cell classes
        let classesToRegister = [BRCEventObject.self, BRCDataObject.self]
        for objClass in classesToRegister {
            let cellClass: (AnyClass!) = BRCDataObjectTableViewCell.cellClassForDataObjectClass(objClass)
            let nib = UINib(nibName: NSStringFromClass(cellClass), bundle: nil)
            let reuseIdentifier = cellClass.cellIdentifier()
            self.tableView!.registerNib(nib, forCellReuseIdentifier: reuseIdentifier)
        }
        self.tableView.registerClass(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.kReuseIdentifier)
    }
    
    func getCurrentLocation() -> CLLocation {
        let appDelegate = BRCAppDelegate.sharedAppDelegate()
        let currentLocation = appDelegate.locationManager.location
        return currentLocation
    }
    
    func refreshNearbyItems() {
        let currentLocation = getCurrentLocation()
        let boxSize: CLLocationDistance = 500
        let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, boxSize, boxSize)
        BRCDatabaseManager.sharedInstance().queryObjectsInRegion(region, completionQueue: dispatch_get_main_queue(), resultsBlock: { (results: [AnyObject]!) -> Void in
            // TODO: Filter & sort items
            let nearbyObjects = results as! [BRCDataObject]
            let options = BRCDataSorterOptions()
            BRCDataSorter.sortDataObjects(nearbyObjects, options: options, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
                self.nearbyArt = art
                self.nearbyEvents = events
                self.nearbyCamps = camps
                if BRCDatabaseManager.sharedInstance().rTreeIndex != nil {
                    self.emptyListText = EmptyListLabelText.Nothing
                }
                self.tableView.reloadData()
            })
        })
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        refreshNearbyItems()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func hasNearbyObjects() -> Bool {
        if nearbyArt.count > 0 || nearbyCamps.count > 0 || nearbyEvents.count > 0 {
            return true
        }
        return false
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if !hasNearbyObjects() {
            return 1
        }
        return 3
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !hasNearbyObjects() {
            return 1
        }
        let tableSection = TableSection(rawValue: section)!
        switch tableSection {
        case TableSection.Events:
            return nearbyEvents.count
        case TableSection.Camps:
            return nearbyCamps.count
        case TableSection.Art:
            return nearbyArt.count
        default:
            return 0
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !hasNearbyObjects() {
            return nil
        }
        let tableSection = TableSection(rawValue: section)!
        switch tableSection {
        case TableSection.Events:
            if nearbyEvents.count == 0 { return nil }
            return "Events"
        case TableSection.Camps:
            if nearbyCamps.count == 0 { return nil }
            return "Camps"
        case TableSection.Art:
            if nearbyArt.count == 0 { return nil }
            return "Art"
        default:
            return nil
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let tableSection = TableSection(rawValue: section)!
        switch tableSection {
        case TableSection.Events:
            if nearbyEvents.count == 0 { return 0 }
        case TableSection.Camps:
            if nearbyCamps.count == 0 { return 0 }
        case TableSection.Art:
            if nearbyArt.count == 0 { return 0 }
        }
        return UITableViewAutomaticDimension
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
        
        var dataObject: BRCDataObject? = nil
        let tableSection = TableSection(rawValue: indexPath.section)!
        let row = indexPath.row
        switch tableSection {
        case TableSection.Events:
            dataObject = nearbyEvents[row]
        case TableSection.Camps:
            dataObject = nearbyCamps[row]
        case TableSection.Art:
            dataObject = nearbyArt[row]
        }
        
        let dataObjectClass = dataObject!.dynamicType
        let cellClass: (AnyClass!) = BRCDataObjectTableViewCell.cellClassForDataObjectClass(dataObjectClass)
        let reuseIdentifier = cellClass.cellIdentifier()
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! BRCDataObjectTableViewCell
        cell.dataObject = dataObject
        cell.updateDistanceLabelFromLocation(getCurrentLocation())
        cell.favoriteButtonAction = { () -> Void in
            let dataCopy = dataObject!.copy() as! BRCDataObject
            dataCopy.isFavorite = cell.favoriteButton.selected
            BRCDatabaseManager.sharedInstance().readWriteConnection!.asyncReadWriteWithBlock({ (transaction: YapDatabaseReadWriteTransaction) -> Void in
                transaction.setObject(dataCopy, forKey: dataCopy.uniqueID, inCollection: dataCopy.dynamicType.collection())
            }, completionQueue:dispatch_get_main_queue(), completionBlock: { () -> Void in
                self.refreshNearbyItems()
            })
        }
        return cell
    }
    
}
