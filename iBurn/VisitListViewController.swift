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
    case wantToVisit = "Want to Visit"
    case visited = "Visited" 
    case all = "All"
}

public class VisitListViewController: ObjectListViewController {
    
    // MARK: - Properties
    
    private var currentFilter: VisitFilter = .wantToVisit
    private let filterControl = UISegmentedControl(items: VisitFilter.allCases.map { $0.rawValue })
    private var refreshTimer: Timer?
    
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
        super.viewDidLoad()
        
        setupViews()
        setupFilter()
        configureGroupTransformer()
        updateViewForSelectedFilter()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh view when visit status might have changed
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Private Methods

private extension VisitListViewController {
    
    func setupViews() {
        // Setup filter control as table header
        setupFilterControl()
    }
    
    func setupFilter() {
        // Default to "All"
        filterControl.selectedSegmentIndex = 2
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
    }
    
    func configureGroupTransformer() {
        // Use emoji for the sidebar index
        listCoordinator.tableViewAdapter.groupTransformer = { group in
            switch group {
            case BRCVisitStatusGroupWantToVisit:
                return "⭐"
            case BRCVisitStatusGroupVisited:
                return "✓"
            default:
                return group
            }
        }
    }
    
    func setupFilterControl() {
        // Create a container view for the segmented control
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(filterControl)
        
        NSLayoutConstraint.activate([
            filterControl.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            filterControl.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            filterControl.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 16),
            filterControl.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            // Add explicit height constraint for the container
            containerView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Set as table header view with proper autolayout
        tableView.tableHeaderView = containerView
        
        // Force layout to ensure proper sizing
        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()
        
        // Update the table header view to recognize the height
        tableView.tableHeaderView = containerView
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
        case .wantToVisit:
            groupFilter = .names([BRCVisitStatusGroupWantToVisit])
        case .visited:
            groupFilter = .names([BRCVisitStatusGroupVisited])
        case .all:
            // Only show Want to Visit and Visited, not Unvisited
            groupFilter = .names([BRCVisitStatusGroupWantToVisit, 
                                  BRCVisitStatusGroupVisited])
        }
        
        // Update the groups in the view handler
        listCoordinator.tableViewAdapter.viewHandler.groups = groupFilter
        
        // Reload the table
        tableView.reloadData()
    }
}