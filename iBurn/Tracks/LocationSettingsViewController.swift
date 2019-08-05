//
//  LocationSettingsViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/2/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import UIKit

final class LocationSettingsViewController: UIViewController {
    // MARK: - Init
    
    init() {
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Location Settings", comment: "")
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LocationSettingsViewController {
    func deleteAll() {
        
    }
}
