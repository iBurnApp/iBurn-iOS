//
//  YapDatabaseConnection+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

public extension YapDatabaseConnection {
    func read<T>(_ block: @escaping ((YapDatabaseReadTransaction) -> T?)) -> T? {
        var object: T? = nil
        read { transaction in
            object = block(transaction)
        }
        return object
    }
}
