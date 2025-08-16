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

public class VisitListViewController: UIViewController {
    
    // MARK: - Properties
    
    private var currentFilter: VisitFilter = .wantToVisit
    private let filterControl = UISegmentedControl(items: VisitFilter.allCases.map { $0.rawValue })
    private var listCoordinator: ListCoordinator!
    private var refreshTimer: Timer?
    
    public var tableView = UITableView.iBurnTableView(style: .grouped)
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupFilter()
        updateViewForSelectedFilter()
        definesPresentationContext = true
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNavigationBarColors(animated)
        searchWillAppear()
        
        // Refresh view when visit status might have changed
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchDidAppear()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tableView.setColorTheme(Appearance.currentColors, animated: false)
        setColorTheme(Appearance.currentColors, animated: false)
    }
}

// MARK: - Private Methods

private extension VisitListViewController {
    
    func setupViews() {
        // Add table view to view hierarchy
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup filter control as table header
        setupFilterControl()
        
        // Setup search button
        setupSearchButton()
        
        // Setup map button  
        setupMapButton()
    }
    
    func setupFilter() {
        // Default to "Want to Visit"
        filterControl.selectedSegmentIndex = 0
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
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
            filterControl.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16)
        ])
        
        // Set as table header view
        containerView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 60)
        tableView.tableHeaderView = containerView
    }
    
    @objc func filterChanged() {
        guard filterControl.selectedSegmentIndex >= 0 else { return }
        currentFilter = VisitFilter.allCases[filterControl.selectedSegmentIndex]
        updateViewForSelectedFilter()
    }
    
    func updateViewForSelectedFilter() {
        let dbManager = BRCDatabaseManager.shared
        let viewName: String
        
        switch currentFilter {
        case .wantToVisit:
            viewName = dbManager.wantToVisitObjectsViewName
        case .visited:
            viewName = dbManager.visitedObjectsViewName
        case .all:
            viewName = dbManager.dataObjectsViewName
        }
        
        // Create new coordinator with the selected view
        listCoordinator = ListCoordinator(
            viewName: viewName,
            searchViewName: dbManager.searchEverythingView,
            tableView: tableView
        )
        listCoordinator.parent = self
        
        // Reload the table
        tableView.reloadData()
    }
}

// MARK: - SearchCooordinator

extension VisitListViewController: SearchCooordinator {
    var searchController: UISearchController {
        return listCoordinator.searchDisplayManager.searchController
    }
}

// MARK: - MapButtonHelper

extension VisitListViewController: MapButtonHelper {
    @objc func mapButtonPressed(_ sender: Any?) {
        let dataSource = YapViewAnnotationDataSource(viewHandler: listCoordinator.tableViewAdapter.viewHandler)
        let mapVC = MapListViewController(dataSource: dataSource)
        navigationController?.pushViewController(mapVC, animated: true)
    }
}