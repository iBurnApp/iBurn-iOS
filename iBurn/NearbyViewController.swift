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
        setupMapButton()
        setupFilter()
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
        guard let currentLocation = getCurrentLocation() else { return }
        let region = MKCoordinateRegion.init(center: currentLocation.coordinate, latitudinalMeters: searchDistance, longitudinalMeters: searchDistance)
        emptyListText = EmptyListLabelText.Loading
        BRCDatabaseManager.shared.queryObjects(in: region, completionQueue: DispatchQueue.main, resultsBlock: { (results) -> Void in
            let nearbyObjects = results
            let options = BRCDataSorterOptions()
            options.sortOrder = .distance(currentLocation)
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
        setupDistanceStepper()
        tableHeaderView.addSubview(tableHeaderLabel)
        tableHeaderView.addSubview(distanceStepper)
        tableHeaderView.addSubview(filterControl)
        distanceStepper.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        tableHeaderLabel.autoAlignAxis(ALAxis.horizontal, toSameAxisOf: distanceStepper)
        tableHeaderLabel.autoPinEdge(ALEdge.right, to: ALEdge.left, of: distanceStepper)
        tableHeaderLabel.autoPinEdge(toSuperviewMargin: ALEdge.left)
        distanceStepper.autoPinEdge(toSuperviewMargin: ALEdge.right)
        filterControl.autoPinEdge(.top, to: .bottom, of: distanceStepper, withOffset: 8)
        filterControl.autoPinEdges(toSuperviewMarginsExcludingEdge: .top)
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
    func mapButtonPressed(_ sender: Any) {
        var annotations: [MGLAnnotation] = []
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
        mapVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(mapVC, animated: true)
    }
}
