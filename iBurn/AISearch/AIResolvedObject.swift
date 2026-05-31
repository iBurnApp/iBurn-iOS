//
//  AIResolvedObject.swift
//  iBurn
//
//  A resolved PlayaDB object (uid → concrete model) used by AI result views for
//  display and navigation. Lives in a neutral file so it survives the AI Guide rewrite.
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaDB

enum AIResolvedObject {
    case art(ArtObject)
    case camp(CampObject)
    case event(EventObject)
    case mutantVehicle(MutantVehicleObject)

    var objectType: DataObjectType {
        switch self {
        case .art: return .art
        case .camp: return .camp
        case .event: return .event
        case .mutantVehicle: return .mutantVehicle
        }
    }
}
