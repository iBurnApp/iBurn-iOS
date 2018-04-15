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

class NearbyViewController: SortedViewController {

    fileprivate var searchDistance: CLLocationDistance = 500
    
    let tableHeaderLabel: UILabel = UILabel()
    let distanceStepper: UIStepper = UIStepper()
    let tableHeaderView: UIView = UIView()
    
    @objc required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style, extensionName: ext)
        emptyDetailText = "Try a bigger search area."
    }
    
    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    // MARK: - View cycle
    
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
        let region = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, searchDistance, searchDistance)
        emptyListText = EmptyListLabelText.Loading
        BRCDatabaseManager.shared.queryObjects(in: region, completionQueue: DispatchQueue.main, resultsBlock: { (results) -> Void in
            let nearbyObjects = results as! [BRCDataObject]
            let options = BRCDataSorterOptions()
            options.sortOrder = .distance(currentLocation)
            BRCDataSorter.sortDataObjects(nearbyObjects, options: options, completionQueue: DispatchQueue.main, callbackBlock: { (events, art, camps) -> (Void) in
                self.processSortedData(events, art: art, camps: camps, completion: completion)
            })
        })
    }
    
    func refreshHeaderLabel() {
        let labelText: NSMutableAttributedString = NSMutableAttributedString()
        let font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        let attributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: font]
        labelText.append(NSAttributedString(string: "Within ", attributes: attributes))
        labelText.append(TTTLocationFormatter.brc_humanizedString(forDistance: searchDistance))
        tableHeaderLabel.attributedText = labelText
        tableHeaderLabel.sizeToFit()
    }
    
    func refreshTableHeaderView() {
        refreshHeaderLabel()
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 45)
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
        setupDistanceStepper()
        tableHeaderView.addSubview(tableHeaderLabel)
        tableHeaderView.addSubview(distanceStepper)
        tableHeaderLabel.autoAlignAxis(ALAxis.horizontal, toSameAxisOf: distanceStepper)
        tableHeaderLabel.autoPinEdge(ALEdge.right, to: ALEdge.left, of: distanceStepper)
        tableHeaderLabel.autoPinEdge(toSuperviewMargin: ALEdge.left)
        distanceStepper.autoAlignAxis(toSuperviewMarginAxis: ALAxis.horizontal)
        distanceStepper.autoPinEdge(toSuperviewMargin: ALEdge.right)
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
        distanceStepper.addTarget(self, action: #selector(NearbyViewController.stepperValueChanged(_:)), for: UIControlEvents.valueChanged)
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
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if !hasTableItems() {
            return 0
        }
        if section == 0 {
            return 25
        }
        return UITableViewAutomaticDimension
    }

}
