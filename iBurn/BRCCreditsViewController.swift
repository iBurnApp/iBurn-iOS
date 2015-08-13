//
//  BRCCreditsViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/9/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import Mantle
import VTAcknowledgementsViewController
import Parse

public class SubtitleCell: UITableViewCell {
    static let kReuseIdentifier = "kSubtitleIdentifier"

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: UITableViewCellStyle.Subtitle, reuseIdentifier: SubtitleCell.kReuseIdentifier)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum SectionInfo: Int {
    case People = 0
    case Licenses
}

class BRCCreditsViewController: UITableViewController {
    
    var creditsInfoArray:[BRCCreditsInfo] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        let dataBundle = NSBundle.brc_dataBundle()
        let creditsURL = dataBundle.URLForResource("credits", withExtension:"json")
        let creditsData = NSData(contentsOfURL: creditsURL!)
        var error: NSError? = nil
        let creditsArray: NSArray = NSJSONSerialization.JSONObjectWithData(creditsData!, options: nil, error: &error) as! NSArray
        let creditsInfo = MTLJSONAdapter.modelsOfClass(
            BRCCreditsInfo.self,
            fromJSONArray: creditsArray as [AnyObject],
            error: &error)
        self.creditsInfoArray = creditsInfo as! [BRCCreditsInfo]
        assert(self.creditsInfoArray.count > 0, "Empty credits info!")
        
        self.tableView.registerClass(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.kReuseIdentifier)
        self.tableView.rowHeight = 55
    }
    
    override func viewWillAppear(animated: Bool) {
        PFAnalytics.trackEventInBackground("Credits", block: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == SectionInfo.People.rawValue {
            return self.creditsInfoArray.count
        } else if section == SectionInfo.Licenses.rawValue {
            return 1
        }
        return 0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == SectionInfo.People.rawValue {
            return "Thank you!"
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(SubtitleCell.kReuseIdentifier, forIndexPath: indexPath) as! UITableViewCell
        // style cell
        cell.textLabel!.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        cell.detailTextLabel!.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        cell.detailTextLabel!.textColor = UIColor.lightGrayColor()
        cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
        // set body
        if indexPath.section == SectionInfo.People.rawValue {
            let creditsInfo = self.creditsInfoArray[indexPath.row]
            cell.textLabel!.text = creditsInfo.name
            cell.detailTextLabel!.text = creditsInfo.blurb
            
        } else if indexPath.section == SectionInfo.Licenses.rawValue {
            cell.textLabel!.text = "Open Source Licenses"
            cell.detailTextLabel!.text = nil
        }
        return cell
    }
    
    // MARK: - Table view delegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == SectionInfo.People.rawValue {
            let creditsInfo = self.creditsInfoArray[indexPath.row]
            let url = creditsInfo.url
            BRCAppDelegate.openURL(url, fromViewController: self)
        } else if indexPath.section == SectionInfo.Licenses.rawValue {
            let ackVC = BRCAcknowledgementsViewController(headerLabel: nil)
            self.navigationController!.pushViewController(ackVC, animated: true)
        }
    }

}
