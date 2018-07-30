//
//  UITableView+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation


extension UITableView {
    public static func iBurnTableView() -> UITableView {
        let tableView = UITableView()
        tableView.registerCustomCellClasses()
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
        return tableView
    }
}
