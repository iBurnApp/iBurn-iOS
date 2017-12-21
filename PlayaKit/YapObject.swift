//
//  YapObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase



public struct YapKeyCollection {
    public let key: String
    public let collection: String
    
    public init(key: String, collection: String) {
        self.key = key
        self.collection = collection
    }
}

extension YapKeyCollection {
    public func fetch(_ transaction: YapDatabaseReadTransaction) -> Any? {
        return transaction.object(forKey: key, inCollection: collection)
    }
}

public protocol YapStorable {
    var yapKeyCollection: YapKeyCollection { get }
    /// Default collection for objects of this type
    static var defaultYapCollection: String { get }
}

public protocol YapObjectFetching: YapStorable {
    func refetch(_ transaction: YapDatabaseReadTransaction) -> Self?
    func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T?
    /// Fetches from default collection `defaultYapCollection`
    static func fetch(_ transaction: YapDatabaseReadTransaction, yapKey: String) -> Self?
    static func fetch(_ transaction: YapDatabaseReadTransaction, yapKeyCollection: YapKeyCollection) -> Self?
    static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, yapKeyCollection: YapKeyCollection, ofType: T.Type) -> T?
    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool
}

public extension YapObjectFetching {
    
    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool {
        let storage = yapKeyCollection
        return transaction.hasObject(forKey: storage.key, inCollection: storage.collection)
    }
    
    public static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, yapKeyCollection: YapKeyCollection, ofType: T.Type) -> T? {
        let object = yapKeyCollection.fetch(transaction) as? T
        return object
    }
    
    public func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T? {
        let object: T? = ofType.fetch(transaction, yapKeyCollection: yapKeyCollection, ofType: ofType)
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

public extension YapObjectProtocol {
    public func touch(_ transaction: YapDatabaseReadWriteTransaction) {
        let storage = yapKeyCollection
        transaction.touchObject(forKey: storage.key, inCollection: storage.collection)
    }
    
    public func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
        let storage = yapKeyCollection
        transaction.setObject(self, forKey: storage.key, inCollection: storage.collection, withMetadata: metadata)
    }
    
    public func upsert(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
        if exists(transaction) && metadata == nil {
            replace(transaction)
        } else {
            save(transaction, metadata: metadata)
        }
    }
    
    public func replace(_ transaction: YapDatabaseReadWriteTransaction) {
        let storage = yapKeyCollection
        transaction.replace(self, forKey: storage.key, inCollection: storage.collection)
    }
    
    public func remove(_ transaction: YapDatabaseReadWriteTransaction) {
        let storage = yapKeyCollection
        transaction.removeObject(forKey: storage.key, inCollection: storage.collection)
    }
}

public class YapObject: YapObjectProtocol {
    public var yapKey: String
    
    public init(yapKey: String) {
        self.yapKey = yapKey
    }
}

extension YapObject: YapObjectFetching {
    /// Fetches from class's default collection `defaultYapCollection`
    public static func fetch(_ transaction: YapDatabaseReadTransaction, yapKey: String) -> Self? {
        let collection = self.defaultYapCollection
        let yapKeyCollection = YapKeyCollection(key: yapKey, collection: collection)
        let object = fetch(transaction, yapKeyCollection: yapKeyCollection)
        return object
    }
    
    public static func fetch(_ transaction: YapDatabaseReadTransaction, yapKeyCollection: YapKeyCollection) -> Self? {
        let object = YapObject.fetch(transaction, yapKeyCollection: yapKeyCollection, ofType: self)
        return object
    }
    
    public func refetch(_ transaction: YapDatabaseReadTransaction) -> Self? {
        let object = refetch(transaction, ofType: type(of: self))
        return object
    }
}

extension YapObject: YapStorable {
    
    public var yapKeyCollection: YapKeyCollection {
        return YapKeyCollection(key: yapKey, collection: yapCollection)
    }
    
    open var yapCollection: String {
        return type(of: self).defaultYapCollection
    }
    
    open static var defaultYapCollection: String {
        return NSStringFromClass(self)
    }
}


