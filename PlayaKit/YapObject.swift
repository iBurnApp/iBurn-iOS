//
//  YapObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

public struct YapStorage {
    let key: String
    let collection: String
    
    public func fetch(_ transaction: YapDatabaseReadTransaction) -> Any? {
        return transaction.object(forKey: key, inCollection: collection)
    }
}

public protocol YapObjectStorage {
    var yapStorage: YapStorage { get }
    /// Default collection for objects of this type
    static var defaultYapCollection: String { get }
}

public protocol YapObjectFetching: YapObjectStorage {
    func refetch(_ transaction: YapDatabaseReadTransaction) -> Self?
    func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T?
    static func fetch(_ transaction: YapDatabaseReadTransaction, yapStorage: YapStorage) -> Self?
    static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, yapStorage: YapStorage, ofType: T.Type) -> T?
    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool
}

public extension YapObjectFetching {
    
    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool {
        let storage = yapStorage
        return transaction.hasObject(forKey: storage.key, inCollection: storage.collection)
    }
    
    public static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, yapStorage: YapStorage, ofType: T.Type) -> T? {
        let object = yapStorage.fetch(transaction) as? T
        return object
    }
    
    public func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T? {
        let object: T? = ofType.fetch(transaction, yapStorage: yapStorage, ofType: ofType)
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
        let storage = yapStorage
        transaction.touchObject(forKey: storage.key, inCollection: storage.collection)
    }
    
    public func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
        let storage = yapStorage
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
        let storage = yapStorage
        transaction.replace(self, forKey: storage.key, inCollection: storage.collection)
    }
    
    public func remove(_ transaction: YapDatabaseReadWriteTransaction) {
        let storage = yapStorage
        transaction.removeObject(forKey: storage.key, inCollection: storage.collection)
    }
}

open class YapObject: NSObject, YapObjectProtocol, Codable {
    open var yapKey = UUID().uuidString
    
    public override init() {
    }
    
    public convenience init(yapKey: String) {
        self.init()
        self.yapKey = yapKey
    }
    
    // MARK: Codable
    private enum CodingKeys: String, CodingKey { case yapKey }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        yapKey = try container.decode(String.self, forKey: .yapKey)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(yapKey, forKey: .yapKey)
    }
}

extension YapObject: YapObjectFetching {
    public static func fetch(_ transaction: YapDatabaseReadTransaction, yapStorage: YapStorage) -> Self? {
        let object = YapObject.fetch(transaction, yapStorage: yapStorage, ofType: self)
        return object
    }
    
    public func refetch(_ transaction: YapDatabaseReadTransaction) -> Self? {
        let object = refetch(transaction, ofType: type(of: self))
        return object
    }
}

extension YapObject: YapObjectStorage {
    
    public var yapStorage: YapStorage {
        return YapStorage(key: yapKey, collection: yapCollection)
    }
    
    open var yapCollection: String {
        return type(of: self).defaultYapCollection
    }
    
    open static var defaultYapCollection: String {
        return NSStringFromClass(self)
    }
}


