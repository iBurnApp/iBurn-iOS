//
//  BRCEmbargo+swift.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

protocol BRCEmbargoInterface {
    func canShowLocation(for data: BRCData) -> Bool
}

extension BRCEmbargo: BRCEmbargoInterface {
    func canShowLocation(for data: BRCData) -> Bool {
        guard let dataObject = data as? BRCDataObject else {
            return false
        }
        return Self.canShowLocation(for: dataObject)
    }
}
