//
//  VisitListViewController.swift
//  iBurn
//
//  Created by Claude on 2025-08-16.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase

public enum VisitFilter: String, CaseIterable {
    case all = "All"
    case wantToVisit = "Want to Visit"
    case visited = "Visited"
}

public class VisitListViewController: ObjectListViewController {
    
    // MARK: - Properties
    
    private var currentFilter: VisitFilter = .all
    private let filterControl = UISegmentedControl(items: VisitFilter.allCases.map { $0.rawValue })
    
    // MARK: - Init
    
    public init() {
        let dbManager = BRCDatabaseManager.shared
        super.init(viewName: dbManager.allObjectsGroupedByVisitStatusViewName,
                   searchViewName: dbManager.searchEverythingView)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        self.tableView = UITableView.iBurnTableView(style: .grouped)
        super.viewDidLoad()
        
        setupViews()
        setupFilter()
        setupTableViewAdapter()
        updateViewForSelectedFilter()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh the view to ensure it shows the latest visit status changes
        BRCDatabaseManager.shared.refreshVisitStatusGroupedView {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
}

// MARK: - Private Methods

private extension VisitListViewController {
    
    func setupViews() {
        // Setup filter control as table header
        setupFilterControl()
    }
    
    func setupFilter() {
        // Default to "All" (first segment)
        filterControl.selectedSegmentIndex = 0
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
    }
    
    func setupTableViewAdapter() {
        // Configure table view adapter for section headers
        listCoordinator.tableViewAdapter.showSectionIndexTitles = false
        listCoordinator.tableViewAdapter.showSectionHeaderTitles = true
        
        // Transform group names to readable section titles
        listCoordinator.tableViewAdapter.groupTransformer = { group in
            switch group {
            case BRCVisitStatusGroupWantToVisit:
                return "⭐ Want to Visit"
            case BRCVisitStatusGroupVisited:
                return "✅ Visited"
            default:
                return group
            }
        }
    }
    
    func setupFilterControl() {
        // Set filter control as table header (simpler approach like FavoritesViewController)
        tableView.tableHeaderView = filterControl
    }
    
    @objc func filterChanged() {
        guard filterControl.selectedSegmentIndex >= 0 else { return }
        currentFilter = VisitFilter.allCases[filterControl.selectedSegmentIndex]
        updateViewForSelectedFilter()
    }
    
    func updateViewForSelectedFilter() {
        // Update the view handler's groups based on selected filter
        let groupFilter: YapViewHandler.MappingsGroups
        
        switch currentFilter {
        case .all:
            // Show both Want to Visit and Visited groups
            groupFilter = .names([BRCVisitStatusGroupWantToVisit, 
                                  BRCVisitStatusGroupVisited])
        case .wantToVisit:
            groupFilter = .names([BRCVisitStatusGroupWantToVisit])
        case .visited:
            groupFilter = .names([BRCVisitStatusGroupVisited])
        }
        
        // Update the groups in the view handler
        listCoordinator.tableViewAdapter.viewHandler.groups = groupFilter
        
        // Reload the table
        tableView.reloadData()
    }
}
