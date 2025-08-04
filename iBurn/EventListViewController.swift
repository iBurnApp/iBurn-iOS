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
public class EventListViewController: UIViewController {
    
    // MARK: - Public Properties
    
    public let viewName: String
    public let searchViewName: String
    
    // MARK: - Private Properties
    
    internal let listCoordinator: ListCoordinator
    private let tableView = UITableView.iBurnTableView()
    private let dayPicker = ASDayPicker()
    private var selectedDay: Date {
        didSet {
            replaceTimeBasedEventMappings()
        }
    }
    private var dayObserver: NSKeyValueObservation?
    private var loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Init
    
    @objc public init(viewName: String,
                      searchViewName: String) {
        self.viewName = viewName
        self.searchViewName = searchViewName
        self.listCoordinator = ListCoordinator(viewName: viewName,
                                               searchViewName: searchViewName,
                                               tableView: tableView)
        self.selectedDay = YearSettings.dayWithinFestival(.present)
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupDayPicker()
        setupTableView()
        setupFilterButton()
        setupListCoordinator()
        setupSearchButton()
        setupMapButton()
        definesPresentationContext = true
        
        view.addSubview(tableView)
        tableView.edgeAnchors == view.edgeAnchors
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchWillAppear()
        refreshNavigationBarColors(animated)
        dayPicker.setColorTheme(Appearance.currentColors, animated: true)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchDidAppear()
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshNavigationBarColors(false)
        dayPicker.setColorTheme(Appearance.currentColors, animated: false)
    }
}


private extension EventListViewController {
    
    // MARK: - Setup
    
    func setupTableView() {
        let size = CGSize(width: tableView.bounds.width, height: 65)
        dayPicker.frame = CGRect(origin: .zero, size: size)
        tableView.tableHeaderView = dayPicker
    }
    
    func setupListCoordinator() {
        self.listCoordinator.parent = self
        let groupTransformer: (String) -> String = {
            let components = $0.components(separatedBy: " ")
            guard let hourString = components.last,
                var hour = Int(hourString) else {
                return $0
            }
            hour = hour % 12
            if hour == 0 {
                hour = 12
            }
            return "\(hour)"
        }
        self.listCoordinator.searchDisplayManager.tableViewAdapter.groupTransformer = GroupTransformers.searchGroup
        self.listCoordinator.tableViewAdapter.groupTransformer = groupTransformer
        replaceTimeBasedEventMappings()
    }
    
    func setupFilterButton() {
        let filter = UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(filterButtonPressed(_:)))
        let loading = UIBarButtonItem(customView: self.loadingIndicator)
        self.navigationItem.rightBarButtonItems = [filter, loading]
    }
    
    func setupDayPicker() {
        dayPicker.daysScrollView.isScrollEnabled = true
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

    
    @objc func filterButtonPressed(_ sender: Any) {
        let filterVC = EventsFilterViewController {
            self.updateFilteredViews()
        }
        let nav = NavigationController(rootViewController: filterVC)
        // this is needed to fix a crash on iOS 16 beta 4
        // [<_UISheetActiveDetent 0x600001391140> valueForUndefinedKey:]: this class is not key value coding-compliant for the key _type.
        if #available(iOS 16.0, *) {
            nav.modalPresentationStyle = .fullScreen
        }
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
        self.listCoordinator.tableViewAdapter.viewHandler.groups = .filterSort({ (group, transaction) -> Bool in
            return group.contains(selectedDayString)
        }, { (group1, group2, transaction) -> ComparisonResult in
            return group1.compare(group2)
        })
        let searchSelectedDayOnly = UserSettings.searchSelectedDayOnly
        
        self.listCoordinator.searchDisplayManager.tableViewAdapter.viewHandler.groups = .filterSort({ (group, transaction) -> Bool in
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

extension EventListViewController: SearchCooordinator {
    var searchController: UISearchController {
        return listCoordinator.searchDisplayManager.searchController
    }
}

extension ASDayPicker: ColorTheme {
    public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        weekdayTextColor = colors.detailColor
        dateTextColor = colors.primaryColor
        selectedWeekdayTextColor = colors.primaryColor
        outOfRangeDateTextColor = colors.detailColor
    }
}

extension EventListViewController: MapButtonHelper {
    func setupMapButton() {
        let mapImage = UIImage(systemName: "map")
        let map = UIBarButtonItem(image: mapImage, style: .plain) { [weak self] (button) in
            self?.mapButtonPressed(button)
        }
        navigationItem.leftBarButtonItem = map
    }
    
    func mapButtonPressed(_ sender: Any?) {
        let dataSource = YapViewAnnotationDataSource(viewHandler: listCoordinator.tableViewAdapter.viewHandler)
        let mapVC = MapListViewController(dataSource: dataSource)
        navigationController?.pushViewController(mapVC, animated: true)
    }
}
