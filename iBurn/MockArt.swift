//
//  MockArt.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
@testable import iBurn

struct MockArt: BRCArt {
    // BRCData
    var playaLocationDescription: String?
    var burnerMapLocationDescription: String?
    var burnerMapAddressDescription: String?
    var burnerMapShortAddressDescription: String?

    // BRCArt
    let name: String
}
