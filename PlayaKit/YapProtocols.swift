//
//  YapObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaKit
import YapDatabase
//
//public protocol YapStorable {
//    var yapKey: String { get }
//    var yapCollection: String { get }
//    /// Default collection for objects of this type
//    static var defaultYapCollection: String { get }
//}
//
//public protocol YapObjectFetching: YapStorable {
//    func refetch(_ transaction: YapDatabaseReadTransaction) -> Self?
//    func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T?
//    /// Fetches from default collection `defaultYapCollection`
//    static func fetch(_ transaction: YapDatabaseReadTransaction, key: String) -> Self?
//    static func fetch(_ transaction: YapDatabaseReadTransaction, key: String, collection: String) -> Self?
//    static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, key: String, collection: String, ofType: T.Type) -> T?
//    func exists(_ transaction: YapDatabaseReadTransaction) -> Bool
//}
//
//extension YapObjectFetching {
//
//    public func exists(_ transaction: YapDatabaseReadTransaction) -> Bool {
//        return transaction.hasObject(forKey: yapKey, inCollection: yapCollection)
//    }
//
//    public static func fetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, key: String, collection: String, ofType: T.Type) -> T? {
//        let object = transaction.object(forKey: key, inCollection: collection) as? T
//        return object
//    }
//
//    public func refetch<T: YapObjectProtocol>(_ transaction: YapDatabaseReadTransaction, ofType: T.Type) -> T? {
//        let object: T? = ofType.fetch(transaction, key: yapKey, collection: yapCollection, ofType: ofType)
//        return object
//    }
//}
//
//public protocol YapObjectSaving {
//    func touch(_ transaction: YapDatabaseReadWriteTransaction)
//    func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?)
//    func upsert(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?)
//    func replace(_ transaction: YapDatabaseReadWriteTransaction)
//    func remove(_ transaction: YapDatabaseReadWriteTransaction)
//}
//
//public protocol YapObjectProtocol: YapObjectSaving, YapObjectFetching { }
//
//extension YapObjectProtocol {
//    public func touch(_ transaction: YapDatabaseReadWriteTransaction) {
//        transaction.touchObject(forKey: yapKey, inCollection: yapCollection)
//    }
//
//    public func save(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
//        transaction.setObject(self, forKey: yapKey, inCollection: yapCollection, withMetadata: metadata)
//    }
//
//    public func upsert(_ transaction: YapDatabaseReadWriteTransaction, metadata: Any?) {
//        if exists(transaction) && metadata == nil {
//            replace(transaction)
//        } else {
//            save(transaction, metadata: metadata)
//        }
//    }
//
//    public func replace(_ transaction: YapDatabaseReadWriteTransaction) {
//        transaction.replace(self, forKey: yapKey, inCollection: yapCollection)
//    }
//
//    public func remove(_ transaction: YapDatabaseReadWriteTransaction) {
//        transaction.removeObject(forKey: yapKey, inCollection: yapCollection)
//    }
//}
//
//extension APIObject: YapObjectProtocol {
//    public var yapKey: String {
//        return uniqueId
//    }
//
//    public var yapCollection: String {
//        return type(of: self).defaultYapCollection
//    }
//
//    public static var defaultYapCollection: String {
//        return NSStringFromClass(self)
//    }
//
//    /// Fetches from class's default collection `defaultYapCollection`
//    public static func fetch(_ transaction: YapDatabaseReadTransaction, key: String) -> Self? {
//        let collection = self.defaultYapCollection
//        let object = fetch(transaction, key: key, collection: collection)
//        return object
//    }
//
//    public static func fetch(_ transaction: YapDatabaseReadTransaction, key: String, collection: String) -> Self? {
//        let object = APIObject.fetch(transaction, key: key, collection: collection, ofType: self)
//        return object
//    }
//
//    public func refetch(_ transaction: YapDatabaseReadTransaction) -> Self? {
//        let object = refetch(transaction, ofType: type(of: self))
//        return object
//    }
//}
//
//public protocol EventFetching: EventProtocol {
//    func hostedByCamp(_ transaction: YapDatabaseReadTransaction) -> CampProtocol?
//    func hostedByArt(_ transaction: YapDatabaseReadTransaction) -> ArtProtocol?
//}
//
//extension EventFetching {
//    public func hostedByCamp(_ transaction: YapDatabaseReadTransaction) -> CampProtocol? {
//        guard let yapKey = self.hostedByCamp else { return nil }
//        let camp = Camp.fetch(transaction, key: yapKey)
//        return camp
//    }
//    public func hostedByArt(_ transaction: YapDatabaseReadTransaction) -> ArtProtocol? {
//        guard let yapKey = self.hostedByArt else { return nil }
//        let art = Art.fetch(transaction, key: yapKey)
//        return art
//    }
//}
