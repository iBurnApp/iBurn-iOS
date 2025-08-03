//
//  NearbyViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import MapKit
import PureLayout
import SwiftUI
import PlayaGeocoder

public enum NearbyFilter: String {
    case all = "All"
    case event = "Events"
    case art = "Art"
    case camp = "Camps"
    /// this is the order that the filters appear
    static let allValues: [NearbyFilter] = [.all, .art, .camp, .event]
}

class NearbyViewController: SortedViewController {

    fileprivate var searchDistance: CLLocationDistance = 500
    
    let tableHeaderLabel: UILabel = UILabel()
    let distanceStepper: UIStepper = UIStepper()
    let tableHeaderView: UIView = UIView()
    private let filterControl = UISegmentedControl(items: NearbyFilter.allValues.map { $0.rawValue })
    
    // MARK: - Time Shift Properties
    private var timeShiftConfig: TimeShiftConfiguration? {
        didSet {
            updateTimeShiftButton()
            updateTimeShiftInfoLabel()
            UserSettings.nearbyTimeShiftConfig = timeShiftConfig
        }
    }
    private var timeShiftBarButton: UIBarButtonItem?
    private let timeShiftInfoLabel = UILabel()
    
    private var searchRegion: MKCoordinateRegion? {
        guard let currentLocation = getCurrentLocation() else { return nil }
        return MKCoordinateRegion.init(center: currentLocation.coordinate, latitudinalMeters: searchDistance, longitudinalMeters: searchDistance)
    }
    
    @objc required init(style: UITableView.Style, extensionName ext: String) {
        super.init(style: style, extensionName: ext)
        emptyDetailText = "Try a bigger search area."
    }
    
    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    // MARK: - View cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Restore saved time shift config
        timeShiftConfig = UserSettings.nearbyTimeShiftConfig
        
        setupMapButton()
        setupFilter()
        setupTimeShiftButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTableHeaderView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (_) -> Void in
            self.refreshTableHeaderView()
        }, completion:nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    internal override func refreshTableItems(_ completion: @escaping ()->()) {
        guard let currentLocation = getCurrentLocation(),
        let region = searchRegion else { return }
        emptyListText = EmptyListLabelText.Loading
        BRCDatabaseManager.shared.queryObjects(in: region, completionQueue: DispatchQueue.main, resultsBlock: { (results) -> Void in
            let nearbyObjects = results
            let options = BRCDataSorterOptions()
            options.sortOrder = .distance(currentLocation)
            
            // Use time-shifted date for filtering
            if let config = self.timeShiftConfig {
                options.now = config.date
            } else {
                options.now = Date.present
            }
            
            // Always use standard filtering - BRCDataSorter will use options.now for comparisons
            options.showExpiredEvents = false
            options.showFutureEvents = false
            
            BRCDataSorter.sortDataObjects(nearbyObjects, options: options, completionQueue: DispatchQueue.main, callbackBlock: { (_events, _art, _camps) -> (Void) in
                var events = _events
                var art = _art
                var camps = _camps
                switch self.selectedFilter {
                case .all:
                    break
                case .event:
                    art = []
                    camps = []
                case .art:
                    events = []
                    camps = []
                case .camp:
                    art = []
                    events = []
                }
                self.processSortedData(events, art: art, camps: camps, completion: completion)
            })
        })
    }
    
    func refreshHeaderLabel() {
        let labelText: NSMutableAttributedString = NSMutableAttributedString()
        let font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font]
        labelText.append(NSAttributedString(string: "Within ", attributes: attributes))
        labelText.append(TTTLocationFormatter.brc_humanizedString(forDistance: searchDistance))
        tableHeaderLabel.attributedText = labelText
        tableHeaderLabel.sizeToFit()
    }
    
    func refreshTableHeaderView() {
        refreshHeaderLabel()
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 85)
        tableView.tableHeaderView = tableHeaderView
    }
    
    override func setupTableView() {
        super.setupTableView()
        setupTableHeaderView()
    }
    
    func setupTableHeaderView() {
        tableHeaderLabel.textAlignment = NSTextAlignment.left
        tableHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceStepper.translatesAutoresizingMaskIntoConstraints = false
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup time shift info label
        timeShiftInfoLabel.font = .preferredFont(forTextStyle: .caption1)
        timeShiftInfoLabel.textColor = .systemOrange
        timeShiftInfoLabel.textAlignment = .center
        timeShiftInfoLabel.numberOfLines = 0
        timeShiftInfoLabel.isHidden = true
        timeShiftInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        setupDistanceStepper()
        tableHeaderView.addSubview(tableHeaderLabel)
        tableHeaderView.addSubview(distanceStepper)
        tableHeaderView.addSubview(filterControl)
        tableHeaderView.addSubview(timeShiftInfoLabel)
        
        distanceStepper.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        tableHeaderLabel.autoAlignAxis(ALAxis.horizontal, toSameAxisOf: distanceStepper)
        tableHeaderLabel.autoPinEdge(ALEdge.right, to: ALEdge.left, of: distanceStepper)
        tableHeaderLabel.autoPinEdge(toSuperviewMargin: ALEdge.left)
        distanceStepper.autoPinEdge(toSuperviewMargin: ALEdge.right)
        filterControl.autoPinEdge(.top, to: .bottom, of: distanceStepper, withOffset: 8)
        filterControl.autoPinEdges(toSuperviewMarginsExcludingEdge: .top)
        
        // Time shift info label constraints
        timeShiftInfoLabel.autoPinEdge(.top, to: .bottom, of: filterControl, withOffset: 8)
        timeShiftInfoLabel.autoPinEdge(toSuperviewMargin: .left)
        timeShiftInfoLabel.autoPinEdge(toSuperviewMargin: .right)
        timeShiftInfoLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8, relation: .greaterThanOrEqual)
        
        tableHeaderView.translatesAutoresizingMaskIntoConstraints = true
        tableHeaderView.autoresizingMask = [ .flexibleHeight, .flexibleWidth ]
        refreshTableHeaderView()
    }
    
    func setupDistanceStepper() {
        // units in CLLocationDistance (meters)
        distanceStepper.minimumValue = 50
        distanceStepper.maximumValue = 3200 // approx 2 miles
        distanceStepper.value = searchDistance
        distanceStepper.stepValue = 150
        distanceStepper.addTarget(self, action: #selector(NearbyViewController.stepperValueChanged(_:)), for: UIControl.Event.valueChanged)
    }
    
    @objc func stepperValueChanged(_ sender: AnyObject?) {
        if let stepper = sender as? UIStepper {
            searchDistance = stepper.value
            refreshTableHeaderView()
            refreshTableItems({ () -> Void in
                self.tableView.reloadData()
            })
        }
    }
    
    @objc func filterValueChanged(_ sender: UISegmentedControl) {
        let value = selectedFilter
        UserSettings.nearbyFilter = value
        updateFilter(value)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !hasTableItems() {
            return 0
        }
        if section == 0 {
            return 25
        }
        return UITableView.automaticDimension
    }
    
    // MARK: - Time Shift Methods
    
    private func setupTimeShiftButton() {
        timeShiftBarButton = UIBarButtonItem(
            title: timeShiftButtonTitle,
            style: .plain,
            target: self,
            action: #selector(timeShiftButtonPressed)
        )
        
        updateTimeShiftButton()
        navigationItem.leftBarButtonItem = timeShiftBarButton
    }
    
    private func updateTimeShiftButton() {
        guard let button = timeShiftBarButton else { return }
        
        button.title = timeShiftButtonTitle
        
        if timeShiftConfig?.isActive == true {
            button.tintColor = .systemOrange
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.systemOrange,
                .font: UIFont.systemFont(ofSize: 17, weight: .medium)
            ]
            button.setTitleTextAttributes(attributes, for: .normal)
        } else {
            button.tintColor = nil
            button.setTitleTextAttributes(nil, for: .normal)
        }
    }
    
    private var timeShiftButtonTitle: String {
        guard let config = timeShiftConfig, config.isActive else {
            return "Now"
        }
        
        let interval = config.date.timeIntervalSince(Date.present)
        if abs(interval) < 60 {
            return "Now"
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        
        if let formatted = formatter.string(from: abs(interval)) {
            return interval >= 0 ? "+\(formatted)" : "-\(formatted)"
        }
        
        return "Shifted"
    }
    
    @objc internal func timeShiftButtonPressed() {
        // Create ViewModel with current state
        let viewModel = TimeShiftViewModel(
            currentConfiguration: timeShiftConfig,
            currentLocation: getCurrentLocation()
        )
        
        // Set up completion handlers
        viewModel.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        
        viewModel.onApply = { [weak self] config in
            self?.applyTimeShift(config)
            self?.dismiss(animated: true)
        }
        
        // Create and present the view controller
        let timeShiftVC = TimeShiftViewController(viewModel: viewModel)
        present(timeShiftVC, animated: true)
    }
    
    private func applyTimeShift(_ config: TimeShiftConfiguration) {
        timeShiftConfig = config.isActive ? config : nil
        
        refreshTableItems { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    private func updateTimeShiftInfoLabel() {
        if let config = timeShiftConfig, config.isActive {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            var infoText = "⏰ \(formatter.string(from: config.date))"
            
            // Add location info
            if let location = config.location {
                infoText += " 📍 "
                
                // Geocode the location asynchronously
                PlayaGeocoder.shared.asyncReverseLookup(location.coordinate) { [weak self] address in
                    DispatchQueue.main.async {
                        guard let self = self,
                              let currentConfig = self.timeShiftConfig,
                              currentConfig.location?.coordinate.latitude == location.coordinate.latitude,
                              currentConfig.location?.coordinate.longitude == location.coordinate.longitude else { return }
                        
                        // Update with geocoded address
                        var updatedText = "⏰ \(formatter.string(from: currentConfig.date)) 📍 "
                        updatedText += address ?? "Unknown Location"
                        self.timeShiftInfoLabel.text = updatedText
                        self.adjustTableHeaderHeight()
                    }
                }
                
                // Show coordinates while geocoding
                infoText += String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
            }
            
            timeShiftInfoLabel.text = infoText
            timeShiftInfoLabel.textColor = .systemOrange
            timeShiftInfoLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
            timeShiftInfoLabel.isHidden = false
            
            adjustTableHeaderHeight()
        } else {
            timeShiftInfoLabel.isHidden = true
            timeShiftInfoLabel.text = nil
            tableHeaderView.frame.size.height = 85
            
            // Reassign to trigger update 
            let oldHeaderView = tableView.tableHeaderView
            tableView.tableHeaderView = nil
            tableView.tableHeaderView = oldHeaderView
        }
    }
    
    private func adjustTableHeaderHeight() {
        // Force layout and adjust height
        timeShiftInfoLabel.sizeToFit()
        let baseHeight: CGFloat = 85
        let labelHeight = timeShiftInfoLabel.frame.height
        let newHeight = baseHeight + labelHeight + 16
        
        tableHeaderView.frame.size.height = newHeight
        
        // Force constraints update
        tableHeaderView.setNeedsLayout()
        tableHeaderView.layoutIfNeeded()
        
        // Reassign to trigger update 
        let oldHeaderView = tableView.tableHeaderView
        tableView.tableHeaderView = nil
        tableView.tableHeaderView = oldHeaderView
    }
    
    override func getCurrentLocation() -> CLLocation? {
        // Use time-shifted location if available
        if let config = timeShiftConfig, let location = config.location {
            return location
        }
        return super.getCurrentLocation()
    }
    
    // MARK: - Location Override Status
    func isLocationOverridden() -> Bool {
        return timeShiftConfig?.location != nil
    }

}

private extension NearbyViewController {
    var selectedFilter: NearbyFilter {
        guard filterControl.selectedSegmentIndex >= 0 else {
            return .all
        }
        return NearbyFilter.allValues[filterControl.selectedSegmentIndex]
    }
    
    func setupFilter() {
        filterControl.addTarget(self, action: #selector(filterValueChanged(_:)), for: .valueChanged)
        
        let userFilter = UserSettings.nearbyFilter
        let index = NearbyFilter.allValues.firstIndex(of: userFilter) ?? 0
        filterControl.selectedSegmentIndex = index
        updateFilter(userFilter)
    }
    
    private func updateFilter(_ newFilter: NearbyFilter) {
        refreshTableItems({ () -> Void in
            self.tableView.reloadData()
        })
    }
}

extension NearbyViewController: MapButtonHelper {
    func mapButtonPressed(_ sender: Any?) {
        var annotations: [MLNAnnotation] = []
        BRCDatabaseManager.shared.uiConnection.read { (t) in
            sections.forEach { (section) in
                section.objects.forEach({ (object) in
                    guard let annotation = object.annotation(transaction: t) else { return }
                    annotations.append(annotation)
                })
            }
        }
        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        navigationController?.pushViewController(mapVC, animated: true)
    }
}
