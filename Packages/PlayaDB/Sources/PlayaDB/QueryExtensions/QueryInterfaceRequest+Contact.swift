import GRDB

// MARK: - Web URL Queries

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding, RowDecoder.ColumnSet: WebUrlColumns {
    private static var webColumns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Filter to only objects with a URL.
    public func withUrl() -> Self {
        filter(Self.webColumns.url != nil)
    }

    /// Filter by URL pattern.
    public func withUrl(matching pattern: String) -> Self {
        filter(Self.webColumns.url.like("%\(pattern)%"))
    }
}

// MARK: - Contact Email Queries

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding, RowDecoder.ColumnSet: ContactEmailColumns {
    private static var emailColumns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Filter to only objects with contact email.
    public func withContactEmail() -> Self {
        filter(Self.emailColumns.contactEmail != nil)
    }

    /// Filter by email domain.
    public func withEmailDomain(_ domain: String) -> Self {
        filter(Self.emailColumns.contactEmail.like("%@\(domain)"))
    }
}

// MARK: - Hometown Queries

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding, RowDecoder.ColumnSet: HometownColumns {
    private static var hometownColumns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Filter to only objects with hometown specified.
    public func withHometown() -> Self {
        filter(Self.hometownColumns.hometown != nil)
    }

    /// Filter by hometown.
    public func fromHometown(_ hometown: String) -> Self {
        filter(Self.hometownColumns.hometown.like("%\(hometown)%"))
    }

    /// Order by hometown alphabetically.
    public func orderedByHometown() -> Self {
        order(Self.hometownColumns.hometown.asc)
    }
}

// MARK: - Location String Queries

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding, RowDecoder.ColumnSet: LocationStringColumns {
    private static var locationColumns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Filter to only objects with location string information.
    public func withLocationString() -> Self {
        filter(Self.locationColumns.locationString != nil)
    }

    /// Filter by location string pattern.
    public func atLocation(matching pattern: String) -> Self {
        filter(Self.locationColumns.locationString.like("%\(pattern)%"))
    }
}
