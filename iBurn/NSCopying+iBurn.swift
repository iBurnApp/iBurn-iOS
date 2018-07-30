//
//  NSCopying.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

extension NSCopying {
    /// Creates a deep copy of the object
    func copyAsSelf() -> Self? {
        return self.copy() as? Self
    }
}
