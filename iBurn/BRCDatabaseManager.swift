//
//  BRCDatabaseManager.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

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
    
    @objc public func makeUpdateInfoView() -> YapDatabaseView {
        let options = YapDatabaseViewOptions()
        options.allowedCollections = .init(filterBlock: { collection in
            (collection as? String) == BRCUpdateInfo.yapCollection
        })
        let yapView = YapDatabaseAutoView(
            grouping: .withKeyBlock({ _, _, _ in
                "all"
            }), sorting: .withObjectBlock({ t, _, _, _, obj1, _, _, obj2 in
                if let obj1 = obj1 as? BRCUpdateInfo,
                   let obj2 = obj2 as? BRCUpdateInfo
                {
                    return obj1.fileName.compare(obj2.fileName)
                }
                return .orderedSame
            }),
            versionTag: "4",
            options: options
        )
        return yapView
    }
    
    @objc public static let updateInfoViewName = "BRCUpdateInfoView"
    
    @objc public func registerUpdateInfoView() -> Bool {
        let view = makeUpdateInfoView()
        return self.database.register(view, withName: Self.updateInfoViewName)
    }
}
