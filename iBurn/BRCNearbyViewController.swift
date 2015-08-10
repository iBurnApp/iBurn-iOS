//
//  BRCNearbyViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import MapKit

class BRCNearbyViewController: UITableViewController {

    var nearbyObjects: [BRCDataObject] = []
    
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
            self.nearbyObjects = results as! [BRCDataObject]
            let sortedObjects = self.nearbyObjects.sorted({ $0.title < $1.title })
            self.nearbyObjects = sortedObjects
            self.tableView.reloadData()
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

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.nearbyObjects.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let dataObject = nearbyObjects[indexPath.row]
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
    
}
