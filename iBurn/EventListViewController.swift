//
//  EventListViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit
import Anchorage
import ASDayPicker

@objc
public final class EventListViewController: UIViewController {
    
    // MARK: - Public Properties
    
    public let viewName: String
    public let searchViewName: String
    
    // MARK: - Private Properties
    
    private let stackView = UIStackView()
    private let listCoordinator: ListCoordinator
    private let tableView = UITableView.iBurnTableView()
    private let dayPicker = ASDayPicker()
    private var selectedDay: Date {
        didSet {
            replaceTimeBasedEventMappings()
        }
    }
    private var dayObserver: NSKeyValueObservation?
    private var loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    // MARK: - Init
    
    @objc public init(viewName: String,
                      searchViewName: String) {
        self.viewName = viewName
        self.searchViewName = searchViewName
        self.listCoordinator = ListCoordinator(viewName: viewName,
                                               searchViewName: searchViewName,
                                               tableView: tableView)
        self.selectedDay = YearSettings.dayWithinFestival(Date())
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupDayPicker()
        setupStackView()
        setupFilterButton()
        setupListCoordinator()
        setupSearchButton()
        
        view.addSubview(stackView)
        stackView.edgeAnchors == view.edgeAnchors
    }
}


private extension EventListViewController {
    
    // MARK: - Setup
    
    func setupSearchButton() {
        let search = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchButtonPressed(_:)))
        self.navigationItem.leftBarButtonItem = search
    }
    
    func setupListCoordinator() {
        self.listCoordinator.parent = self
        replaceTimeBasedEventMappings()
    }
    
    func setupFilterButton() {
        let filter = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(filterButtonPressed(_:)))
        let loading = UIBarButtonItem(customView: self.loadingIndicator)
        self.navigationItem.rightBarButtonItems = [filter, loading]
    }
    
    func setupStackView() {
        stackView.axis = .vertical
        stackView.addArrangedSubview(dayPicker)
        stackView.addArrangedSubview(tableView)
    }
    
    func setupDayPicker() {
        dayPicker.heightAnchor == 65.0
        dayPicker.daysScrollView.isScrollEnabled = false
        dayPicker.setStart(YearSettings.eventStart, end: YearSettings.eventEnd)
        dayPicker.weekdayTitles = ASDayPicker.weekdayTitles(withLocaleIdentifier: nil, length: 3, uppercase: true)
        dayPicker.selectedDateBackgroundImage = UIImage(named: "BRCDateSelection")
        dayObserver = dayPicker.observe(\.selectedDate) { [weak self] (object, change) in
            let date = YearSettings.dayWithinFestival(object.selectedDate)
            self?.selectedDay = date
        }
        dayPicker.selectedDate = self.selectedDay
    }
    
    // MARK: - UI Actions
    
    @objc func searchButtonPressed(_ sender: Any) {
        present(listCoordinator.searchDisplayManager.searchController, animated: true, completion: nil)
    }
    
    @objc func filterButtonPressed(_ sender: Any) {
        let filterVC = BRCEventsFilterTableViewController(delegate: self)
        let nav = UINavigationController(rootViewController: filterVC)
        present(nav, animated: true, completion: nil)
    }
    
    // MARK: - UI Refresh
    
    func updateFilteredViews() {
        loadingIndicator.startAnimating()
        BRCDatabaseManager.shared.refreshEventFilteredViews(withSelectedDay: self.selectedDay) {
            self.loadingIndicator.stopAnimating()
        }
    }
    
    func replaceTimeBasedEventMappings() {
        let selectedDayString = DateFormatter.eventGroupDateFormatter.string(from: self.selectedDay)
        self.listCoordinator.tableViewAdapter.viewHandler.groups = .block({ (group, transaction) -> Bool in
            return group.contains(selectedDayString)
        }, { (group1, group2, transaction) -> ComparisonResult in
            return group1.compare(group2)
        })
        let searchSelectedDayOnly = UserSettings.searchSelectedDayOnly
        
        self.listCoordinator.searchDisplayManager.tableViewAdapter.viewHandler.groups = .block({ (group, transaction) -> Bool in
            if searchSelectedDayOnly {
                return group.contains(selectedDayString)
            } else {
                return true
            }
        }, { (group1, group2, transaction) -> ComparisonResult in
            return group1.compare(group2)
        })
    }
}

extension EventListViewController: BRCEventsFilterTableViewControllerDelegate {
    public func didSetNewFilterSettings(_ viewController: BRCEventsFilterTableViewController) {
        updateFilteredViews()
    }
}
