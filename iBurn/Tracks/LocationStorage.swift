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
    
    @objc(setup:) public class func setup() throws {
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("LocationHistory.sqlite")
        self.shared = try LocationStorage(path: databaseURL.path)
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
    
    func setupDatabase(_ application: UIApplication) throws {
        dbQueue.setupMemoryManagement(in: application)
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
