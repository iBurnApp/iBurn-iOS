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

open class SubtitleCell: UITableViewCell {
    static let kReuseIdentifier = "kSubtitleIdentifier"

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: UITableViewCellStyle.subtitle, reuseIdentifier: SubtitleCell.kReuseIdentifier)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum SectionInfo: Int {
    case people = 0
    case licenses
}

class BRCCreditsViewController: UITableViewController {
    
    var creditsInfoArray:[BRCCreditsInfo] = []

    init () {
        super.init(style: UITableViewStyle.grouped)
    }

    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    fileprivate override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let dataBundle = Bundle.brc_data
        let creditsURL = dataBundle.url(forResource: "credits", withExtension:"json")
        let creditsData = try? Data(contentsOf: creditsURL!)
        do {
            if let creditsArray = try JSONSerialization.jsonObject(with: creditsData!, options:JSONSerialization.ReadingOptions()) as? NSArray {
                let creditsInfo = try MTLJSONAdapter.models(of: BRCCreditsInfo.self,fromJSONArray: creditsArray as [AnyObject])
                self.creditsInfoArray = creditsInfo as! [BRCCreditsInfo]
                assert(self.creditsInfoArray.count > 0, "Empty credits info!")
            }
        } catch {
            
        }
        
        
        self.tableView.register(SubtitleCell.self, forCellReuseIdentifier: SubtitleCell.kReuseIdentifier)
        self.tableView.rowHeight = 55
    }
    
    override func viewWillAppear(_ animated: Bool) {
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == SectionInfo.people.rawValue {
            return self.creditsInfoArray.count
        } else if section == SectionInfo.licenses.rawValue {
            return 1
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == SectionInfo.people.rawValue {
            return "Thank you!"
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SubtitleCell.kReuseIdentifier, for: indexPath) 
        // style cell
        cell.textLabel!.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        cell.detailTextLabel!.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
        cell.detailTextLabel!.textColor = UIColor.lightGray
        cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        // set body
        if indexPath.section == SectionInfo.people.rawValue {
            let creditsInfo = self.creditsInfoArray[indexPath.row]
            cell.textLabel!.text = creditsInfo.name
            cell.detailTextLabel!.text = creditsInfo.blurb
            
        } else if indexPath.section == SectionInfo.licenses.rawValue {
            cell.textLabel!.text = "Open Source Licenses"
            cell.detailTextLabel!.text = nil
        }
        return cell
    }
    
    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == SectionInfo.people.rawValue {
            let creditsInfo = self.creditsInfoArray[indexPath.row]
            if let url = creditsInfo.url {
                BRCAppDelegate.open(url, from: self)
            }
        } else if indexPath.section == SectionInfo.licenses.rawValue {
            let ackVC = BRCAcknowledgementsViewController(headerLabel: nil)
            self.navigationController!.pushViewController(ackVC!, animated: true)
        }
    }

}
