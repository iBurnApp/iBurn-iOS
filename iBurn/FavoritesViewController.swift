//
//  FavoritesViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/17/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase

public enum FavoritesFilter: String {
    case all = "All"
    case event = "Events"
    case art = "Art"
    case camp = "Camps"
    /// this is the order that the filters appear
    static let allValues: [FavoritesFilter] = [.all, .art, .camp, .event]
}

public class FavoritesViewController: ObjectListViewController {
    
    private enum Group: String {
        case event = "BRCEventObject"
        case camp = "BRCCampObject"
        case art = "BRCArtObject"
        var sectionTitle: String? {
            return filter?.rawValue
        }
        var filter: FavoritesFilter? {
            switch self {
            case .art:
                return .art
            case .camp:
                return .camp
            case .event:
                return .event
            }
        }
    }
    
    private let filterControl = UISegmentedControl(items: FavoritesFilter.allValues.map { $0.rawValue })

    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        self.tableView = UITableView.iBurnTableView(style: .grouped)
        super.viewDidLoad()
        setupTableViewAdapter()
        setupFilter()
    }
}

private extension FavoritesViewController {
    
    var selectedFilter: FavoritesFilter {
        guard filterControl.selectedSegmentIndex >= 0 else {
            return .all
        }
        return FavoritesFilter.allValues[filterControl.selectedSegmentIndex]
    }
    
    // MARK: - Setup
    
    func setupFilter() {
        tableView.tableHeaderView = filterControl
        filterControl.addTarget(self, action: #selector(filterValueChanged(_:)), for: .valueChanged)
        
        let userFilter = UserSettings.favoritesFilter
        let index = FavoritesFilter.allValues.firstIndex(of: userFilter) ?? 0
        filterControl.selectedSegmentIndex = index
        updateFilter(userFilter)
    }
    
    func setupTableViewAdapter() {
        listCoordinator.searchDisplayManager.tableViewAdapter.showSectionIndexTitles = false
        listCoordinator.tableViewAdapter.showSectionIndexTitles = false
        listCoordinator.tableViewAdapter.showSectionHeaderTitles = true
        listCoordinator.tableViewAdapter.groupTransformer = {
            guard let group = Group(rawValue: $0), let title = group.sectionTitle else { return $0 }
            return title
        }
    }
    
    // MARK: - UI Interaction
    
    @objc func filterValueChanged(_ sender: UISegmentedControl) {
        let value = selectedFilter
        UserSettings.favoritesFilter = value
        updateFilter(value)
    }
    
    private func updateFilter(_ newFilter: FavoritesFilter) {
        listCoordinator.tableViewAdapter.viewHandler.groups = .filter { (group, _) -> Bool in
            if newFilter == .all {
                return true
            }
            guard let filter = Group(rawValue: group)?.filter else { return false }
            return filter == newFilter
        }
    }
}
