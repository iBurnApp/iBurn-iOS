//
//  BRCDataObject.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

public extension BRCDataObjectTableViewCell {
    /** Mapping between cell identifiers and cell classes */
    public static let cellIdentifiers = [BRCDataObjectTableViewCell.cellIdentifier: BRCDataObjectTableViewCell.self,
                                     BRCArtObjectTableViewCell.cellIdentifier: BRCArtObjectTableViewCell.self,
                                     BRCEventObjectTableViewCell.cellIdentifier: BRCEventObjectTableViewCell.self,
                                     ArtImageCell.cellIdentifier: ArtImageCell.self]
}

public extension BRCDataObject {
    
    /** Returns the cellIdentifier for table cell subclass */
    public var tableCellIdentifier: String {
        var cellIdentifier = BRCDataObjectTableViewCell.cellIdentifier
        if let art = self as? BRCArtObject {
            if art.localThumbnailURL != nil {
                cellIdentifier = ArtImageCell.cellIdentifier
            } else {
                cellIdentifier = BRCArtObjectTableViewCell.cellIdentifier
            }
        } else if let _ = self as? BRCEventObject {
            cellIdentifier = BRCEventObjectTableViewCell.cellIdentifier
        } else if let _ = self as? BRCCampObject {
            cellIdentifier = BRCDataObjectTableViewCell.cellIdentifier
        }
        return cellIdentifier
    }
}
