//
//  MapDetailViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit

class MapAnnotation: NSObject, MGLAnnotation {
    
    weak var parent: BRCDataObject? = nil
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D,
         title: String?,
         subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
    
    convenience init?(object: BRCDataObject) {
        var location = object.location
        var address = object.playaLocation
        if location == nil {
            location = object.burnerMapLocation
        }
        if address == nil {
            address = object.burnerMapLocationString
        }
        guard let loc = location else {
            return nil
        }
        var title = object.title
        if let event = object as? BRCEventObject {
            if let camp = event.campName {
                title = camp
            } else if let art = event.artName {
                title = art
            }
        }
        self.init(coordinate: loc.coordinate, title: title, subtitle: address)
        self.parent = object
    }
    
}

public class MapDetailViewController: BaseMapViewController {
    
    private let dataObject: BRCDataObject
    private let annotation: MapAnnotation?
    
    public init(dataObject: BRCDataObject) {
        self.dataObject = dataObject
        self.annotation = MapAnnotation(object: dataObject)
        super.init()
        if let annotation = annotation {
            mapView.addAnnotation(annotation)
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = dataObject.title
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let annotation = annotation {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100)) {
                let padding = UIEdgeInsetsMake(120, 60, 45, 60)
                self.mapView.brc_showDestination(annotation, animated: animated, padding: padding)
                self.mapView.selectAnnotation(annotation, animated: animated)
            }
        }
    }

    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
