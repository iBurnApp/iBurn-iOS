//
//  MapPinListViewController.swift
//  iBurn
//
//  Created by Claude on 8/3/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre
import CoreLocation

public class MapPinListViewController: SortedViewController {
    
    // MARK: - Properties
    
    private let visibleAnnotations: [MLNAnnotation]
    private let visibleBounds: MLNCoordinateBounds
    
    // MARK: - Init
    
    public init(visibleAnnotations: [MLNAnnotation], visibleBounds: MLNCoordinateBounds) {
        self.visibleAnnotations = visibleAnnotations
        self.visibleBounds = visibleBounds
        // Empty extensionName since we're not using a database extension
        super.init(style: .plain, extensionName: "")
        title = "Visible Pins"
        emptyDetailText = "No pins visible in the current map area."
    }
    
    required public init!(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(style: UITableView.Style, extensionName ext: String) {
        fatalError("init(style:extensionName:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - SortedViewController Override
    
    override func refreshTableItems(_ completion: @escaping () -> ()) {
        // Filter annotations to only DataObjectAnnotations within bounds
        var dataObjects: [BRCDataObject] = []
        
        for annotation in visibleAnnotations {
            guard visibleBounds.contains(annotation.coordinate) else { continue }
            
            if let dataAnnotation = annotation as? DataObjectAnnotation {
                dataObjects.append(dataAnnotation.object)
            }
        }
        
        // Sort using BRCDataSorter
        let options = BRCDataSorterOptions()
        options.showExpiredEvents = true  // Show all events regardless of timing
        options.showFutureEvents = true   // Show all events regardless of timing
        if let currentLocation = getCurrentLocation() {
            options.sortOrder = .distance(currentLocation)
        }
        
        BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: DispatchQueue.main) { (events, art, camps) in
            self.processSortedData(events, art: art, camps: camps, completion: completion)
        }
    }
}

// MARK: - MLNCoordinateBounds Extension

private extension MLNCoordinateBounds {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= sw.latitude &&
               coordinate.latitude <= ne.latitude &&
               coordinate.longitude >= sw.longitude &&
               coordinate.longitude <= ne.longitude
    }
}