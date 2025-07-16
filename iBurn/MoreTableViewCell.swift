//
//  MoreTableViewCell.swift
//  iBurn
//
//  Created by Claude on 7/16/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

class MoreTableViewCell: UITableViewCell {
    static let reuseIdentifier = "MoreTableViewCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: MoreTableViewCell.reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        accessoryType = .disclosureIndicator
        selectionStyle = .default
    }
    
    func configure(title: String, imageName: String?, tag: Int) {
        textLabel?.text = title
        self.tag = tag
        
        if let imageName = imageName {
            imageView?.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        }
    }
    
    func configure(title: String, systemImageName: String?, tag: Int) {
        textLabel?.text = title
        self.tag = tag
        
        if let systemImageName = systemImageName {
            imageView?.image = UIImage(systemName: systemImageName)?.withRenderingMode(.alwaysTemplate)
        }
    }
}