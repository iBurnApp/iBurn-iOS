//
//  BRCEventObjectTableView.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

@objc(BRCEventObjectTableViewCell)
class EventTableViewCell: BRCDataObjectTableViewCell {
    @IBOutlet var hostLabel: UILabel!
    @IBOutlet var eventTypeLabel: UILabel!
    @IBOutlet var locationLabel: UILabel!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func setDataObject(_ dataObject: BRCDataObject, metadata: BRCObjectMetadata) {
        super.setDataObject(dataObject, metadata: metadata)
        guard let viewModel = EventViewModel(data: dataObject, metadata: metadata) else {
            return
        }
        self.rightSubtitleLabel.text = viewModel.timeDescription
        self.rightSubtitleLabel.textColor = viewModel.statusColor
        self.eventTypeLabel.text = viewModel.eventTypeDescription
        
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await viewModel.appear()
            self.hostLabel.text = viewModel.hostName
            self.locationLabel.text = viewModel.locationDescription
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.rightSubtitleLabel.text = nil
        self.eventTypeLabel.text = nil
        self.hostLabel.text = nil
        self.locationLabel.text = nil
        
        self.rightSubtitleLabel.textColor = Appearance.currentColors.detailColor
    }
}

extension EventTableViewCell {
    public override func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        backgroundColor = colors.backgroundColor
        descriptionLabel.textColor = colors.secondaryColor
        titleLabel.textColor = colors.primaryColor
        hostLabel?.textColor = colors.detailColor
        eventTypeLabel.textColor = colors.detailColor
        locationLabel.textColor = colors.detailColor
        subtitleLabel.textColor = colors.detailColor
        rightSubtitleLabel.textColor = colors.detailColor
    }
}
