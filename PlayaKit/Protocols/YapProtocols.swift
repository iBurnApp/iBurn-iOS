//
//  YapObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

public protocol YapStorable {
    var yapKey: String { get }
    var yapCollection: String { get }
    /// Default collection for objects of this type
    static var defaultYapCollection: String { get }
}

public protocol YapObjectFetching: YapStorable {
    func refetch(_ transaction: YapDatabaseReadTransaction) -> Self?
    func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T?
    /// Fetches from default collection `defaultYapCollection`
    static func fetch(_ transaction: YapDatabaseReadTransaction, key: String) -> Self?
    static func fetch(_ transaction: YapDatabaseReadTransaction, key: String, collection: String) -> Self?
    static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, key: String, collection: String, ofType: T.Type) -> T?
    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool
}

extension YapObjectFetching {
    
    public func exists(_ transaction: YapDatabaseReadTransaction) -> Bool {
        return transaction.hasObject(forKey: yapKey, inCollection: yapCollection)
    }
    
    public static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, key: String, collection: String, ofType: T.Type) -> T? {
        let object = transaction.object(forKey: key, inCollection: collection) as? T
        return object
    }
    
    public func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T? {
        let object: T? = ofType.fetch(transaction, key: yapKey, collection: yapCollection, ofType: ofType)
        return object
    }
}

public protocol YapObjectSaving {
    func touch(_ transaction: YapDatabaseReadWriteTransaction)
    func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?)
    func upsert(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?)
    func replace(_ transaction: YapDatabaseReadWriteTransaction)
    func remove(_ transaction: YapDatabaseReadWriteTransaction)
}

public protocol YapObjectProtocol: YapObjectSaving, YapObjectFetching { }

extension YapObjectProtocol {
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
}


