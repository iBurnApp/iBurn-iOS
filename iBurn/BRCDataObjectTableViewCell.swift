//
//  BRCDataObjectTableViewCell.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCDataObjectTableViewCell {
    class func cell(at indexPath: IndexPath,
                    tableView: UITableView,
                    dataObject: DataObject,
                    writeConnection: YapDatabaseConnection) -> UITableViewCell {
        let cellIdentifier = dataObject.object.tableCellIdentifier
        let anyCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        guard let cell = anyCell as? BRCDataObjectTableViewCell else {
            return anyCell
        }
        let currentLocation = BRCAppDelegate.shared.locationManager.location
        cell.setDataObject(dataObject.object, metadata: dataObject.metadata)
        cell.updateDistanceLabel(from: currentLocation, dataObject: dataObject.object)
        cell.favoriteButtonAction = { (cell, isFavorite) in
            writeConnection.readWrite { transaction in
                guard let metadata = dataObject.object.metadata(with: transaction).copyAsSelf() else { return }
                metadata.isFavorite = isFavorite
                dataObject.object.replace(metadata, transaction: transaction)
            }
        }
        if let artCell = cell as? BRCArtObjectTableViewCell, let art = dataObject.object as? BRCArtObject {
            artCell.configurePlayPauseButton(art)
        }
        return cell
    }
}

extension BRCDataObjectTableViewCell {
    public override func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        backgroundColor = colors.backgroundColor
        descriptionLabel.textColor = colors.secondaryColor
        titleLabel.textColor = colors.primaryColor
        subtitleLabel.textColor = colors.detailColor
        rightSubtitleLabel.textColor = colors.detailColor
    }
}
