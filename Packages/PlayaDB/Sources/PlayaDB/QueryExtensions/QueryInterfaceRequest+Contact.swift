//
//  QueryInterfaceRequest+Contact.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import GRDB

// MARK: - Web URL Queries for ArtObject

extension QueryInterfaceRequest where RowDecoder == ArtObject {
    /// Filter to only objects with a URL
    public func withUrl() -> Self {
        self.filter(ArtObject.Columns.url != nil)
    }

    /// Filter by URL pattern
    public func withUrl(matching pattern: String) -> Self {
        self.filter(ArtObject.Columns.url.like("%\(pattern)%"))
    }

    /// Filter to only objects with contact email
    public func withContactEmail() -> Self {
        self.filter(ArtObject.Columns.contactEmail != nil)
    }

    /// Filter by email domain
    public func withEmailDomain(_ domain: String) -> Self {
        self.filter(ArtObject.Columns.contactEmail.like("%@\(domain)"))
    }

    /// Filter to only objects with hometown specified
    public func withHometown() -> Self {
        self.filter(ArtObject.Columns.hometown != nil)
    }

    /// Filter by hometown
    public func fromHometown(_ hometown: String) -> Self {
        self.filter(ArtObject.Columns.hometown.like("%\(hometown)%"))
    }

    /// Order by hometown alphabetically
    public func orderedByHometown() -> Self {
        self.order(ArtObject.Columns.hometown.asc)
    }

    /// Filter to only objects with location string
    public func withLocationString() -> Self {
        self.filter(ArtObject.Columns.locationString != nil)
    }

    /// Filter by location string pattern
    public func atLocation(matching pattern: String) -> Self {
        self.filter(ArtObject.Columns.locationString.like("%\(pattern)%"))
    }
}

// MARK: - Web URL Queries for CampObject

extension QueryInterfaceRequest where RowDecoder == CampObject {
    /// Filter to only objects with a URL
    public func withUrl() -> Self {
        self.filter(CampObject.Columns.url != nil)
    }

    /// Filter by URL pattern
    public func withUrl(matching pattern: String) -> Self {
        self.filter(CampObject.Columns.url.like("%\(pattern)%"))
    }

    /// Filter to only objects with contact email
    public func withContactEmail() -> Self {
        self.filter(CampObject.Columns.contactEmail != nil)
    }

    /// Filter by email domain
    public func withEmailDomain(_ domain: String) -> Self {
        self.filter(CampObject.Columns.contactEmail.like("%@\(domain)"))
    }

    /// Filter to only objects with hometown specified
    public func withHometown() -> Self {
        self.filter(CampObject.Columns.hometown != nil)
    }

    /// Filter by hometown
    public func fromHometown(_ hometown: String) -> Self {
        self.filter(CampObject.Columns.hometown.like("%\(hometown)%"))
    }

    /// Order by hometown alphabetically
    public func orderedByHometown() -> Self {
        self.order(CampObject.Columns.hometown.asc)
    }

    /// Filter to only objects with location string
    public func withLocationString() -> Self {
        self.filter(CampObject.Columns.locationString != nil)
    }

    /// Filter by location string pattern
    public func atLocation(matching pattern: String) -> Self {
        self.filter(CampObject.Columns.locationString.like("%\(pattern)%"))
    }
}

// MARK: - Web URL Queries for EventObject

extension QueryInterfaceRequest where RowDecoder == EventObject {
    /// Filter to only objects with a URL
    public func withUrl() -> Self {
        self.filter(EventObject.Columns.url != nil)
    }

    /// Filter by URL pattern
    public func withUrl(matching pattern: String) -> Self {
        self.filter(EventObject.Columns.url.like("%\(pattern)%"))
    }
}
