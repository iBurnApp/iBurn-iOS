//
//  MockData.swift
//  iBurnTests
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
@testable import iBurn

struct MockData: BRCData {
    let playaLocationDescription: String?
    let burnerMapLocationDescription: String?
    let burnerMapAddressDescription: String?
    let burnerMapShortAddressDescription: String?
    
    init(
        playaLocationDescription: String? = nil,
        burnerMapLocationDescription: String? = nil,
        burnerMapAddressDescription: String? = nil,
        burnerMapShortAddressDescription: String? = nil
    ) {
        self.playaLocationDescription = playaLocationDescription
        self.burnerMapLocationDescription = burnerMapLocationDescription
        self.burnerMapAddressDescription = burnerMapAddressDescription
        self.burnerMapShortAddressDescription = burnerMapShortAddressDescription
    }
}
