//
//  DataViewModel.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation

protocol DataViewModel {
    static func locationDescription(for data: BRCData, embargo: BRCEmbargoInterface) -> String?
}

extension DataViewModel {
    static func locationDescription(for data: BRCData, embargo: BRCEmbargoInterface = BRCEmbargo()) -> String? {
        var locationDescription = data.playaLocationDescription ?? data.burnerMapLocationDescription
        if let event = data as? BRCEvent, locationDescription == nil {
            if event.locationName != nil {
                return "Other Location"
            } else {
                return "Location Unknown"
            }
        }
        
        if embargo.canShowLocation(for: data) {
            return locationDescription
        } else if let burnerLocation = data.burnerMapShortAddressDescription {
            return "BurnerMap: \(burnerLocation)"
        } else if let burnerLocation = data.burnerMapLocationDescription {
            return "BurnerMap: \(burnerLocation)"
        } else {
            return "Location Restricted"
        }
    }
}
