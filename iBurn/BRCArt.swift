//
//  BRCArt.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

protocol BRCArt: BRCData {
    var name: String { get }
}

extension BRCArtObject: BRCArt {
    var name: String {
        title
    }
}
