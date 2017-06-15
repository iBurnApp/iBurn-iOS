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
    
    public init(dataObject: BRCDataObject) {
        self.dataObject = dataObject
        super.init()
        mapView.addAnnotation(dataObject)
        refresh()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    
    private func refresh() {
        title = dataObject.title
        self.mapView.brc_showDestination(dataObject, animated: false)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
