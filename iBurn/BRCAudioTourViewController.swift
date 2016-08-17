//
//  BRCAudioTourViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import UIKit

enum AudioButtonState: String {
    case PlayAll = "Play All"
    case Resume = "Resume"
    case Pause = "Pause"
}

class BRCAudioTourViewController: BRCSortedViewController {
    
    let playAllItemsButton = UIBarButtonItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayAllItemsButton()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.refreshButtonState()
    }
    
    func setupPlayAllItemsButton() {
        refreshButtonState()
        playAllItemsButton.action = #selector(BRCAudioTourViewController.playAllItems(_:))
        playAllItemsButton.target = self
        self.navigationItem.rightBarButtonItem = playAllItemsButton
    }
    
    func refreshButtonState() {
        if let player = BRCAudioPlayer.sharedInstance.player {
            if player.rate > 0 {
                playAllItemsButton.title = AudioButtonState.Pause.rawValue
            } else {
                playAllItemsButton.title = AudioButtonState.Resume.rawValue
            }
        } else {
            playAllItemsButton.title = AudioButtonState.PlayAll.rawValue
        }
    }
    
    internal override func audioPlayerChangeNotification(notification: NSNotification) {
        super.audioPlayerChangeNotification(notification)
        refreshButtonState()
    }
    
    func playAllItems(sender: AnyObject?) {
        if BRCAudioPlayer.sharedInstance.player != nil {
            BRCAudioPlayer.sharedInstance.togglePlayPause()
        } else {
            if let objects = self.sections.first?.objects {
                BRCAudioPlayer.sharedInstance.playAudioTour(objects as! [BRCArtObject])
            }
        }
        refreshButtonState()
    }

    override func refreshTableItems(completion: dispatch_block_t) {
        var art: [BRCArtObject] = []
        BRCDatabaseManager.sharedInstance().readConnection.asyncReadWithBlock({ (transaction: YapDatabaseReadTransaction) -> Void in
            if let viewTransaction = transaction.ext(self.extensionName) as? YapDatabaseViewTransaction {
                viewTransaction.enumerateGroupsUsingBlock({ (group: String!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    viewTransaction.enumerateKeysAndObjectsInGroup(group, usingBlock: { (collection: String!, key: String!, object: AnyObject!, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                        if let dataObject = object as? BRCArtObject {
                            art.append(dataObject)
                        }
                    })
                })
            }
            }, completionBlock: { () -> Void in
                NSLog("Audio Tour count: %d", art.count)
                BRCDataSorter.sortDataObjects(art, options: nil, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
                    self.processSortedData(events, art: art, camps: camps, completion: completion)
                })
        })
    }

}
