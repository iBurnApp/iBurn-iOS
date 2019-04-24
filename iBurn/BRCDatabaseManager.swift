//
//  BRCDatabaseManager.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCDatabaseManager {
    /// When running low on memory, limit caches to 250
    @objc public func reduceCacheLimit() {
        let connections = [self.readWriteConnection,
                           self.backgroundReadConnection,
                           self.uiConnection]
        connections.forEach {
            $0.objectCacheLimit = 250
            $0.metadataCacheLimit = 250
        }
    }
}
