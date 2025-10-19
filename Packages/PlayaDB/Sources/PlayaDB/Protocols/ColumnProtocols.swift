//
//  ColumnProtocols.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import GRDB

// MARK: - Core DataObject Columns

/// Protocol for models with standard DataObject columns
public protocol DataObjectColumns: ColumnExpression {
    static var uid: Self { get }
    static var name: Self { get }
    static var year: Self { get }
    static var description: Self { get }
}

// MARK: - Geographic Columns

/// Protocol for models with GPS location columns
public protocol GeoLocatableColumns: ColumnExpression {
    static var gpsLatitude: Self { get }
    static var gpsLongitude: Self { get }
}

// MARK: - Contact Information Columns

/// Protocol for models with web URL
public protocol WebUrlColumns: ColumnExpression {
    static var url: Self { get }
}

/// Protocol for models with contact email
public protocol ContactEmailColumns: ColumnExpression {
    static var contactEmail: Self { get }
}

/// Protocol for models with hometown
public protocol HometownColumns: ColumnExpression {
    static var hometown: Self { get }
}

// MARK: - Location String Columns

/// Protocol for models with human-readable location string
public protocol LocationStringColumns: ColumnExpression {
    static var locationString: Self { get }
}

// MARK: - Event Occurrence Columns

/// Protocol for event occurrence time columns
public protocol EventOccurrenceColumns: ColumnExpression {
    static var startTime: Self { get }
    static var endTime: Self { get }
}

// MARK: - Model Column Providers

/// Protocol adopted by models that expose their column set for generic query helpers.
public protocol DataObjectColumnProviding: TableRecord {
    associatedtype ColumnSet: DataObjectColumns
    static var columnSet: ColumnSet.Type { get }
}
