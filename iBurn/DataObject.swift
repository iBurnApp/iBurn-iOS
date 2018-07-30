//
//  DataObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc(DataObjectWithMetadata)
public class DataObject: NSObject {
    @objc let object: BRCDataObject
    @objc let metadata: BRCObjectMetadata
    @objc public init(object: BRCDataObject,
                      metadata: BRCObjectMetadata) {
        self.object = object
        self.metadata = metadata
    }
}

@objc public protocol DataObjectProvider: NSObjectProtocol {
    func dataObjectAtIndexPath(_ indexPath: IndexPath) -> DataObject?
}

extension YapViewHandler: DataObjectProvider {
    public func dataObjectAtIndexPath(_ indexPath: IndexPath) -> DataObject? {
        var dataObject: DataObject? = nil
        let _: BRCDataObject? = object(at: indexPath) { (object, transaction) in
            let metadata = object.metadata(with: transaction)
            dataObject = DataObject(object: object, metadata: metadata)
        }
        return dataObject
    }
}
