//
//  BRCCamp.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

protocol BRCCamp: BRCData {
    var name: String { get }
}

extension BRCCampObject: BRCCamp {
    var name: String {
        title
    }
}
