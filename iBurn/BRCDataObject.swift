//
//  BRCDataObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCDataObjectTableViewCell {
    /** Mapping between cell identifiers and cell classes */
    public static let cellIdentifiers = [
        BRCDataObjectTableViewCell.cellIdentifier: BRCDataObjectTableViewCell.self,
        BRCArtObjectTableViewCell.cellIdentifier: BRCArtObjectTableViewCell.self,
        EventTableViewCell.cellIdentifier: EventTableViewCell.self,
        ArtImageCell.cellIdentifier: ArtImageCell.self]
}

extension BRCDataObject {
    
    /** Returns the cellIdentifier for table cell subclass */
    @objc public var tableCellIdentifier: String {
        var cellIdentifier = BRCDataObjectTableViewCell.cellIdentifier
        if let art = self as? BRCArtObject {
            if art.localThumbnailURL != nil {
                cellIdentifier = ArtImageCell.cellIdentifier
            } else {
                cellIdentifier = BRCArtObjectTableViewCell.cellIdentifier
            }
        } else if let _ = self as? BRCEventObject {
            cellIdentifier = EventTableViewCell.cellIdentifier
        } else if let _ = self as? BRCCampObject {
            cellIdentifier = BRCDataObjectTableViewCell.cellIdentifier
        }
        return cellIdentifier
    }
    
    /** Short address e.g. 7:45 & G */
    @objc public var shortBurnerMapAddress: String? {
        guard let string = self.burnerMapLocationString else { return nil }
        let components = string.components(separatedBy: " & ")
        guard let radial = components.first, let street = components.last, street.count > 1 else {
            return self.burnerMapLocationString
        }
        let index = street.index(street.startIndex, offsetBy: 1)
        let trimmedStreet = street[..<index]
        let shortAddress = "\(radial) & \(trimmedStreet)"
        return shortAddress
    }
}


