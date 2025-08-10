//
//  ArtListViewController.swift
//  iBurn
//
//  Created by Claude on 8/10/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase

public class ArtListViewController: ObjectListViewController {
    
    private var filterButton: UIBarButtonItem?
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupFilterButton()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFilterButtonAppearance()
    }
}

private extension ArtListViewController {
    
    // MARK: - Setup
    
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
    
    // MARK: - UI Interaction
    
    @objc private func filterButtonPressed() {
        let filterVC = ArtFilterViewController { [weak self] in
            // Refresh the database view when filter changes
            BRCDatabaseManager.shared.refreshArtFilteredView {
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
        let showOnlyWithEvents = UserSettings.showOnlyArtWithEvents
        filterButton?.image = UIImage(systemName: showOnlyWithEvents ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
    }
}