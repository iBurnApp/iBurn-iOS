//
//  QueryInterfaceRequest+Contact.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import GRDB

// MARK: - Web URL Queries

extension QueryInterfaceRequest {
    /// Filter to only objects with a URL
    public func withUrl() -> Self where RowDecoder.Columns: WebUrlColumns {
        self.filter(RowDecoder.Columns.url != nil)
    }

    /// Filter by URL pattern
    public func withUrl(matching pattern: String) -> Self where RowDecoder.Columns: WebUrlColumns {
        self.filter(RowDecoder.Columns.url.like("%\(pattern)%"))
    }
}

// MARK: - Contact Email Queries

extension QueryInterfaceRequest {
    /// Filter to only objects with contact email
    public func withContactEmail() -> Self where RowDecoder.Columns: ContactEmailColumns {
        self.filter(RowDecoder.Columns.contactEmail != nil)
    }

    /// Filter by email domain
    public func withEmailDomain(_ domain: String) -> Self where RowDecoder.Columns: ContactEmailColumns {
        self.filter(RowDecoder.Columns.contactEmail.like("%@\(domain)"))
    }
}

// MARK: - Hometown Queries

extension QueryInterfaceRequest {
    /// Filter to only objects with hometown specified
    public func withHometown() -> Self where RowDecoder.Columns: HometownColumns {
        self.filter(RowDecoder.Columns.hometown != nil)
    }

    /// Filter by hometown
    public func fromHometown(_ hometown: String) -> Self where RowDecoder.Columns: HometownColumns {
        self.filter(RowDecoder.Columns.hometown.like("%\(hometown)%"))
    }

    /// Order by hometown alphabetically
    public func orderedByHometown() -> Self where RowDecoder.Columns: HometownColumns {
        self.order(RowDecoder.Columns.hometown.asc)
    }
}

// MARK: - Location String Queries

extension QueryInterfaceRequest {
    /// Filter to only objects with location string
    public func withLocationString() -> Self where RowDecoder.Columns: LocationStringColumns {
        self.filter(RowDecoder.Columns.locationString != nil)
    }

    /// Filter by location string pattern
    public func atLocation(matching pattern: String) -> Self where RowDecoder.Columns: LocationStringColumns {
        self.filter(RowDecoder.Columns.locationString.like("%\(pattern)%"))
    }
}
