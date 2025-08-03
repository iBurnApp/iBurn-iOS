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
        updateTableHeaderViewHeight()
    }
    
    func updateTableHeaderViewHeight() {
        // Let the stack view calculate its required size
        let targetSize = CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let size = tableHeaderView.systemLayoutSizeFitting(targetSize, 
                                                          withHorizontalFittingPriority: .required, 
                                                          verticalFittingPriority: .fittingSizeLevel)
        
        // Update header view frame if needed
        if tableHeaderView.frame.size.height != size.height {
            tableHeaderView.frame.size = CGSize(width: view.bounds.width, height: size.height)
            
            // Reassign to trigger table view update
            tableView.tableHeaderView = tableHeaderView
        }
    }
    
    override func setupTableView() {
        super.setupTableView()
        setupTableHeaderView()
    }
    
    func setupTableHeaderView() {
        // Configure labels and controls
        tableHeaderLabel.textAlignment = .left
        
        timeShiftInfoLabel.font = .preferredFont(forTextStyle: .caption1)
        timeShiftInfoLabel.textColor = .systemOrange
        timeShiftInfoLabel.textAlignment = .center
        timeShiftInfoLabel.numberOfLines = 0
        timeShiftInfoLabel.isHidden = true
        
        setupDistanceStepper()
        
        // Create horizontal stack for distance row
        let distanceStackView = UIStackView(arrangedSubviews: [tableHeaderLabel, distanceStepper])
        distanceStackView.axis = .horizontal
        distanceStackView.alignment = .center
        distanceStackView.spacing = 8
        
        // Create main vertical stack view
        let mainStackView = UIStackView(arrangedSubviews: [distanceStackView, filterControl, timeShiftInfoLabel])
        mainStackView.axis = .vertical
        mainStackView.alignment = .fill
        mainStackView.spacing = 12
        mainStackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        mainStackView.isLayoutMarginsRelativeArrangement = true
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add stack view to header
        tableHeaderView.addSubview(mainStackView)
        
        // Constrain stack view to fill header view
        mainStackView.autoPinEdgesToSuperviewEdges()
        
        // Update header view
        updateTableHeaderViewHeight()
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
        return "Warp"
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
            formatter.dateFormat = "EEE MMM d, h:mm a"
            
            var infoText = "Warped: ⏰ \(formatter.string(from: config.date))"
            
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
                        let formatter = DateFormatter()
                        formatter.dateFormat = "EEE MMM d, h:mm a"
                        var updatedText = "Warped: ⏰ \(formatter.string(from: currentConfig.date)) 📍 "
                        updatedText += address ?? "Unknown Location"
                        self.timeShiftInfoLabel.text = updatedText
                        self.updateTableHeaderViewHeight()
                    }
                }
                
                // Show coordinates while geocoding
                infoText += String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
            }
            
            timeShiftInfoLabel.text = infoText
            timeShiftInfoLabel.isHidden = false
            
            updateTableHeaderViewHeight()
        } else {
            timeShiftInfoLabel.isHidden = true
            timeShiftInfoLabel.text = nil
            updateTableHeaderViewHeight()
        }
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
