//
//  MoreSwitchCell.swift
//  iBurn
//
//  Created by Claude on 7/16/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

class MoreSwitchCell: UITableViewCell {
    static let reuseIdentifier = "MoreSwitchCell"
    
    private let switchControl = UISwitch()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: MoreSwitchCell.reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        selectionStyle = .none
        accessoryView = switchControl
    }
    
    func configure(title: String, subtitle: String, imageName: String?, tag: Int, switchTarget: Any?, switchAction: Selector) {
        textLabel?.text = title
        detailTextLabel?.text = subtitle
        self.tag = tag
        
        if let imageName = imageName {
            imageView?.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        }
        
        switchControl.addTarget(switchTarget, action: switchAction, for: .valueChanged)
    }
    
    func configure(title: String, subtitle: String, systemImageName: String?, tag: Int, switchTarget: Any?, switchAction: Selector) {
        textLabel?.text = title
        detailTextLabel?.text = subtitle
        self.tag = tag
        
        if let systemImageName = systemImageName {
            imageView?.image = UIImage(systemName: systemImageName)?.withRenderingMode(.alwaysTemplate)
        }
        
        switchControl.addTarget(switchTarget, action: switchAction, for: .valueChanged)
    }
    
    var isOn: Bool {
        get { return switchControl.isOn }
        set { switchControl.isOn = newValue }
    }
}