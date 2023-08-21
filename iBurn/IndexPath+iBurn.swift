//
//  IndexPath+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/6/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

@objc(BRCIndexPathDirection)
public enum IndexPathDirection: Int {
    case before
    case after
}

extension NSIndexPath {
    @objc public func nextIndexPath(direction: IndexPathDirection, tableView: UITableView) -> NSIndexPath? {
        let indexPath = self as IndexPath
        return indexPath.nextIndexPath(direction: direction, tableView: tableView) as NSIndexPath?
    }
}


extension IndexPath {
    // Inspired by https://akosma.com/2012/04/20/getting-the-next-and-the-previous-nsindexpath-instances/
    public func nextIndexPath(direction: IndexPathDirection, tableView: UITableView) -> IndexPath? {
        let sectionCount = tableView.numberOfSections
        if self.section >= sectionCount {
            return nil
        }
        let rowCount = tableView.numberOfRows(inSection: self.section)
        switch direction {
        case .after:
            let nextRow = self.row + 1
            if nextRow < rowCount {
                return IndexPath(row: nextRow, section: self.section)
            } else {
                let nextSection = self.section + 1
                if (nextSection < sectionCount) {
                    return IndexPath(row: 0, section: nextSection)
                }
            }
        case .before:
            let nextRow = self.row - 1
            if nextRow >= 0 {
                return IndexPath(row: nextRow, section: self.section)
            } else {
                let nextSection = self.section - 1
                if nextSection >= 0 {
                    return IndexPath(row: 0, section: nextSection)
                }
            }
        }
        return nil
    }
}


