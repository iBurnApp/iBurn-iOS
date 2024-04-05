//
//  MockCamp.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
@testable import iBurn

struct MockCamp: BRCCamp {
    // BRCData
    var playaLocationDescription: String?
    var burnerMapLocationDescription: String?
    var burnerMapAddressDescription: String?
    var burnerMapShortAddressDescription: String?
    
    // BRCCamp
    let name: String
}
