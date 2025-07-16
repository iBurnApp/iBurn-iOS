//
//  AppearanceViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation


class AppearanceViewController: UITableViewController {
    
    // MARK: - Initialization
    
    init() {
        super.init(style: .grouped)
        self.title = "Appearance"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    enum Section: Int, CaseIterable {
        case theme = 0
        case imageColors = 1
        
        var title: String? {
            switch self {
            case .theme: return "Theme"
            case .imageColors: return "Image Colors"
            }
        }
        
        var footer: String? {
            switch self {
            case .theme: return "Restart the app for full effect."
            case .imageColors: return "When enabled, uses colors extracted from art images for theming. When disabled, uses the global theme colors."
            }
        }
        
        var rowCount: Int {
            switch self {
            case .theme: return ThemeRow.allCases.count
            case .imageColors: return 1
            }
        }
    }
    
    enum ThemeRow: Int, CaseIterable {
        case system = 0
        case light = 1
        case dark = 2
        
        var title: String {
            switch self {
            case .system: return "System Default"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        var cellTag: CellTag {
            switch self {
            case .system: return .system
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
    
    enum CellTag: Int, CaseIterable {
        case system
        case light
        case dark
        case imageColorsToggle
        
        var theme: AppTheme? {
            switch self {
            case .light:
                return .light
            case .dark:
                return .dark
            case .system:
                return .system
            case .imageColorsToggle:
                return nil
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register standard cell class
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AppearanceCell")
    }
    
    // MARK: - UITableViewDelegate & DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        return sectionType.rowCount
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.footer
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppearanceCell", for: indexPath)
        cell.setColorTheme(Appearance.currentColors, animated: false)
        cell.selectionStyle = .default
        
        // Clear any previous accessory configuration to prevent cell reuse issues
        cell.accessoryView = nil
        cell.accessoryType = .none
        
        guard let sectionType = Section(rawValue: indexPath.section) else {
            fatalError("Invalid section")
        }
        
        switch sectionType {
        case .theme:
            guard let themeRow = ThemeRow(rawValue: indexPath.row) else {
                fatalError("Invalid theme row")
            }
            
            let cellTag = themeRow.cellTag
            cell.textLabel?.text = themeRow.title
            cell.tag = cellTag.rawValue
            
            // Set checkmark based on current theme
            switch cellTag {
            case .system:
                cell.accessoryType = Appearance.theme == .system ? .checkmark : .none
            case .light:
                cell.accessoryType = Appearance.theme == .light ? .checkmark : .none
            case .dark:
                cell.accessoryType = Appearance.theme == .dark ? .checkmark : .none
            case .imageColorsToggle:
                break // Not applicable for theme rows
            }
            
        case .imageColors:
            // Only one row in this section
            cell.textLabel?.text = "Use Image Colors"
            cell.tag = CellTag.imageColorsToggle.rawValue
            
            // Configure the switch for image colors toggle
            let switchControl = UISwitch()
            switchControl.isOn = Appearance.useImageColorsTheming
            switchControl.onTintColor = Appearance.currentColors.primaryColor
            switchControl.addTarget(self, action: #selector(imageColorsToggleChanged(_:)), for: .valueChanged)
            cell.accessoryView = switchControl
        }
        
        cell.textLabel?.textColor = Appearance.currentColors.primaryColor
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cell = tableView.cellForRow(at: indexPath),
        let cellTag = CellTag(rawValue: cell.tag) else {
            return
        }
        switch cellTag {
        case .light, .dark, .system:
            guard let theme = cellTag.theme else { return }
            Appearance.theme = theme
            tableView.reloadData()
            refreshTheme()
        case .imageColorsToggle:
            // Toggle the switch programmatically when cell is tapped
            if let switchControl = cell.accessoryView as? UISwitch {
                switchControl.setOn(!switchControl.isOn, animated: true)
                // Trigger the action manually since we're setting programmatically
                imageColorsToggleChanged(switchControl)
            }
        }
    }
    
    @objc private func imageColorsToggleChanged(_ sender: UISwitch) {
        Appearance.useImageColorsTheming = sender.isOn
        refreshTheme()
    }
}

extension AppearanceViewController {
    func refreshTheme() {
        tableView.setColorTheme(Appearance.currentColors, animated: false)
        refreshGlobalTheme()
    }
}

protocol ThemeRefreshable: UIViewController {
    func refreshGlobalTheme()
}

extension ThemeRefreshable {
    func refreshGlobalTheme() {
        tabBarController?.tabBar.setColorTheme(Appearance.currentColors, animated: false)
        navigationController?.navigationBar.setColorTheme(Appearance.currentColors, animated: false)
        setNeedsStatusBarAppearanceUpdate()
    }
}

extension AppearanceViewController: ThemeRefreshable {}

