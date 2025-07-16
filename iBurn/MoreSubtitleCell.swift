//
//  MoreSubtitleCell.swift
//  iBurn
//
//  Created by Claude on 7/16/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

class MoreSubtitleCell: UITableViewCell, ReusableCell {
    static let reuseIdentifier = "MoreSubtitleCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: MoreSubtitleCell.reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        selectionStyle = .default
        // Subtitle cells don't use disclosure indicators in the storyboard
        accessoryType = .none
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset cell state to defaults to prevent reuse issues
        isUserInteractionEnabled = true
        accessoryType = .none
        textLabel?.textColor = nil
        detailTextLabel?.textColor = nil
        imageView?.image = nil
    }
    
    func configure(title: String, subtitle: String, imageName: String?, tag: Int) {
        textLabel?.text = title
        detailTextLabel?.text = subtitle
        self.tag = tag
        
        if let imageName = imageName {
            imageView?.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        }
    }
    
    func configure(title: String, subtitle: String, systemImageName: String?, tag: Int) {
        textLabel?.text = title
        detailTextLabel?.text = subtitle
        self.tag = tag
        
        if let systemImageName = systemImageName {
            imageView?.image = UIImage(systemName: systemImageName)?.withRenderingMode(.alwaysTemplate)
        }
    }
}