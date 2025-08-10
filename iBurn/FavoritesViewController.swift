//
//  FavoritesViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/17/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase

public enum FavoritesFilter: String, CaseIterable {
    case all = "All"
    case art = "Art"
    case camp = "Camps"
    case event = "Events"
}

public class FavoritesViewController: ObjectListViewController {
    
    private var filterButton: UIBarButtonItem?
    
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
    
    private let filterControl = UISegmentedControl(items: FavoritesFilter.allCases.map { $0.rawValue })

    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        self.tableView = UITableView.iBurnTableView(style: .grouped)
        super.viewDidLoad()
        setupTableViewAdapter()
        setupFilter()
        setupFilterButton()
    }
}

private extension FavoritesViewController {
    
    var selectedFilter: FavoritesFilter {
        guard filterControl.selectedSegmentIndex >= 0 else {
            return .all
        }
        return FavoritesFilter.allCases[filterControl.selectedSegmentIndex]
    }
    
    // MARK: - Setup
    
    func setupFilter() {
        tableView.tableHeaderView = filterControl
        filterControl.addTarget(self, action: #selector(filterValueChanged(_:)), for: .valueChanged)
        
        let userFilter = UserSettings.favoritesFilter
        let index = FavoritesFilter.allCases.firstIndex(of: userFilter) ?? 0
        filterControl.selectedSegmentIndex = index
        updateFilter(userFilter)
    }
    
    func setupFilterButton() {
        let filter = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(filterButtonPressed)
        )
        filterButton = filter
        // Add filter button to existing buttons (map button is already there from parent class)
        var buttons: [UIBarButtonItem] = navigationItem.rightBarButtonItems ?? []
        buttons.insert(filter, at: 0) // Insert filter button before map button
        navigationItem.rightBarButtonItems = buttons
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
    
    @objc private func filterButtonPressed() {
        let filterVC = FavoritesFilterViewController { [weak self] in
            // Refresh the database view when filter changes
            BRCDatabaseManager.shared.refreshFavoritesFilteredView {
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                    self?.updateFilterButtonAppearance()
                }
            }
        }
        let navController = UINavigationController(rootViewController: filterVC)
        present(navController, animated: true)
    }
    
    private func updateFilterButtonAppearance() {
        let showExpired = UserSettings.showExpiredEventsInFavorites
        filterButton?.image = UIImage(systemName: showExpired ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
    }
}

// MARK: - Map Button Override
extension FavoritesViewController {
    override func mapButtonPressed(_ sender: Any?) {
        // Show all items currently visible in the favorites list (respecting filter preferences)
        // The viewHandler already contains the filtered favorites view (everythingFilteredByFavoriteAndExpiration)
        // showAllEvents: true ensures all favorited events are shown, not just currently happening ones
        // Arts and camps are always shown regardless of this setting
        let dataSource = YapViewAnnotationDataSource(viewHandler: listCoordinator.tableViewAdapter.viewHandler, showAllEvents: true)
        let mapVC = MapListViewController(dataSource: dataSource)
        navigationController?.pushViewController(mapVC, animated: true)
    }
}
