//
//  AppearanceViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation


class AppearanceViewController: UITableViewController {
    
    enum CellTag: Int, CaseIterable {
        case system
        case light
        case dark
        
        var theme: AppTheme? {
            switch self {
            case .light:
                return .light
            case .dark:
                return .dark
            case .system:
                return .system
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - UITableViewDelegate & DataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.setColorTheme(Appearance.currentColors, animated: false)
        cell.contentView.subviews.forEach {
            if let label = $0 as? UILabel {
                label.textColor = Appearance.currentColors.primaryColor
            }
        }
        cell.selectionStyle = .none
        guard let cellTag = CellTag(rawValue: cell.tag) else {
            return cell
        }
        var toggled = false
        switch cellTag {
        case .light:
            toggled = Appearance.theme == .light
        case .dark:
            toggled = Appearance.theme == .dark
        case .system:
            toggled = Appearance.theme == .system
        }
        if toggled {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath),
        let cellTag = CellTag(rawValue: cell.tag) else {
            return
        }
        switch cellTag {
        case .light, .dark, .system:
            guard let theme = cellTag.theme else { return }
            Appearance.theme = theme
        }
        tableView.reloadData()
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

extension AppearanceViewController: StoryboardRepresentable {
    static func fromStoryboard() -> UIViewController {
        let storyboard = Storyboard.more
        return storyboard.instantiateViewController(withIdentifier: "Appearance")
    }
}
