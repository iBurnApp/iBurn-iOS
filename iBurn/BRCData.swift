//
//  BRCData.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

protocol BRCData {
    var playaLocationDescription: String? { get }
    
    // Non-embargo'd location information
    var burnerMapLocationDescription: String? { get }
    var burnerMapAddressDescription: String? { get }
    var burnerMapShortAddressDescription: String? { get }
}

extension BRCDataObject: BRCData {
    var playaLocationDescription: String? {
        playaLocation
    }
    
    var burnerMapLocationDescription: String? {
        burnerMapLocationString
    }
    
    var burnerMapAddressDescription: String? {
        burnerMapLocationString
    }
    
    var burnerMapShortAddressDescription: String? {
        shortBurnerMapAddress
    }
}
