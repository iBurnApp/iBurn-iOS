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
    public static let cellIdentifiers = [BRCDataObjectTableViewCell.cellIdentifier: BRCDataObjectTableViewCell.self,
                                     BRCArtObjectTableViewCell.cellIdentifier: BRCArtObjectTableViewCell.self,
                                     BRCEventObjectTableViewCell.cellIdentifier: BRCEventObjectTableViewCell.self,
                                     ArtImageCell.cellIdentifier: ArtImageCell.self]
}

extension BRCDataObject {
    
    /** Returns the cellIdentifier for table cell subclass */
    @objc public var tableCellIdentifier: String {
        var cellIdentifier = BRCDataObjectTableViewCell.cellIdentifier
        
        // Check if object has thumbnail support
        if let thumbnailObject = self as? BRCThumbnailProtocol {
            if thumbnailObject.localThumbnailURL != nil {
                cellIdentifier = ArtImageCell.cellIdentifier
            } else if let _ = self as? BRCArtObject {
                // Art objects without images still get audio support
                cellIdentifier = BRCArtObjectTableViewCell.cellIdentifier
            } else {
                // Other thumbnail objects without images use basic cell
                cellIdentifier = BRCDataObjectTableViewCell.cellIdentifier
            }
        } else if let _ = self as? BRCEventObject {
            cellIdentifier = BRCEventObjectTableViewCell.cellIdentifier
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


