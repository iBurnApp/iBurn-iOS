//
//  LocationStorage.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation
import GRDB
import CoreLocation

public final class LocationStorage: NSObject {
    
    static var shared: LocationStorage?
    
    /// Creates `shared` (if needed) and begins recording breadcrumbs.
    ///
    /// Called from `BRCAppDelegate` at launch. `start()` is invoked here because nothing else
    /// on the launch path does: previously breadcrumbs only began recording after the user
    /// visited More → Location History, which is the one screen that used to call `start()`.
    /// `start()` still honors `UserDefaults.isLocationHistoryDisabled`, so a paused user
    /// stays paused.
    @objc(setup:) public class func setup() throws {
        if let existing = shared {
            existing.start()
            return
        }
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("LocationHistory.sqlite")
        let storage = try LocationStorage(path: databaseURL.path)
        self.shared = storage
        storage.start()
    }
    
    let dbQueue: DatabaseQueue
    private let locationManager: CLLocationManager
    
    init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        
        // Define the database schema
        try LocationStorage.migrator.migrate(dbQueue)
        
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
    }
    
    @objc public func start() {
        guard !UserDefaults.isLocationHistoryDisabled else { return }
        locationManager.startUpdatingLocation()
    }
    
    func restart() {
        stop()
        start()
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createBreadcrumbs2") { db in
            try db.create(table: "breadcrumb") { t in
                t.autoIncrementedPrimaryKey("id")

                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("timestamp", .datetime).notNull()
            }
        }

        return migrator
    }
}

extension LocationStorage: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newCrumbs: [Breadcrumb] = locations.compactMap {
            guard BRCLocations.burningManRegion.contains($0.coordinate) else { return nil }
            return Breadcrumb.from($0)
        }
        dbQueue.asyncWrite({ (db) in
            for var crumb in newCrumbs {
                try crumb.insert(db)
            }
        }) { (db, result) in
            switch result {
            case .success:
                print("Saved breadcrumbs: \(newCrumbs)")
            case .failure(let error):
                print("Error saving breadcrumb: \(error)")
            }
        }
    }
}
