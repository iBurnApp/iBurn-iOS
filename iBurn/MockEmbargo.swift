//
//  MockEmbargo.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
@testable import iBurn

struct MockEmbargo: BRCEmbargoInterface {
    var canShowLocation: Bool = true
    func canShowLocation(for data: iBurn.BRCData) -> Bool {
        canShowLocation
    }
}
