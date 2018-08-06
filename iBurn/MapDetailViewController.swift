//
//  MapDetailViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit

public class MapDetailViewController: BaseMapViewController {
    
    private let dataObject: BRCDataObject
    private let annotation: DataObjectAnnotation?
    
    @objc public init(dataObject: BRCDataObject) {
        self.dataObject = dataObject
        self.annotation = DataObjectAnnotation(object: dataObject)
        super.init()
        if let annotation = annotation {
            mapView.addAnnotation(annotation)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    

}
