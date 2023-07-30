//
//  BRCUpdateInfo.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/23.
//  Copyright © 2023 iBurn. All rights reserved.
//

import Foundation

extension BRCUpdateFetchStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .fetching:
            return "Fetching"
        case .failed:
            return "Failed"
        case .complete:
            return "Complete"
        @unknown default:
            return "Unknown"
        }
    }
}
