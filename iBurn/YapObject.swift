//
//  YapObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public protocol YapObjectProtocol {
    var yapKey: String { get }
    var yapCollection: String { get }
    static var yapCollection: String { get }
    
    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool
    func touch(_ transaction: YapDatabaseReadWriteTransaction)
    func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?)
    func upsert(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?)
    func replace(_ transaction: YapDatabaseReadWriteTransaction)
    func remove(_ transaction: YapDatabaseReadWriteTransaction)
    func refetch(_ transaction: YapDatabaseReadTransaction) -> YapObjectProtocol?
    static func fetch(yapKey: String, transaction: YapDatabaseReadTransaction) -> YapObjectProtocol?
}

open class YapObject: NSObject, YapObjectProtocol {
    
    open let yapKey: String
    open var yapCollection: String {
        return type(of: self).yapCollection
    }
    open static var yapCollection: String {
        return NSStringFromClass(self)
    }

    public init(yapKey: String?) {
        self.yapKey = yapKey ?? UUID().uuidString
    }
    
    
    public func exists(_ transaction: YapDatabaseReadTransaction) -> Bool {
        return transaction.hasObject(forKey: yapKey, inCollection: yapCollection)
    }
    
    public func touch(_ transaction: YapDatabaseReadWriteTransaction) {
        transaction.touchObject(forKey: yapKey, inCollection: yapCollection)
    }
    
    public func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
        transaction.setObject(self, forKey: yapKey, inCollection: yapCollection, withMetadata: metadata)
    }
    
    public func upsert(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
        if exists(transaction) && metadata == nil {
            replace(transaction)
        } else {
            save(transaction, metadata: metadata)
        }
    }
    
    public func replace(_ transaction: YapDatabaseReadWriteTransaction) {
        transaction.replace(self, forKey: yapKey, inCollection: yapCollection)
    }
    
    public func remove(_ transaction: YapDatabaseReadWriteTransaction) {
        transaction.removeObject(forKey: yapKey, inCollection: yapCollection)
    }
    
    public func refetch(_ transaction: YapDatabaseReadTransaction) -> YapObjectProtocol? {
        let object = type(of: self).fetch(yapKey: yapKey, transaction: transaction)
        return object
    }
    
    public static func fetch(yapKey: String, transaction: YapDatabaseReadTransaction) -> YapObjectProtocol? {
        let collection = yapCollection
        let object = transaction.object(forKey: yapKey, inCollection: collection)
        if let object = object as? YapObjectProtocol {
            return object
        }
        return nil
    }
    
    
}
