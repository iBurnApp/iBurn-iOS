//
//  AudioTourViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase

enum AudioButtonState: String {
    case PlayAll = "Play All"
    case Resume = "Resume"
    case Pause = "Pause"
}

class AudioTourViewController: SortedViewController {
    
    let playAllItemsButton = UIBarButtonItem()
    let soundcloudButton = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayAllItemsButton()
        setupSoundcloudButton()
        tableView.tableHeaderView = soundcloudButton
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.refreshButtonState()
    }
    
    func setupSoundcloudButton() {
        soundcloudButton.setTitleColor(.darkText, for: .normal)
        soundcloudButton.setTitle("Open in SoundCloud", for: .normal)
        soundcloudButton.addTarget(self, action: #selector(soundcloudButtonPressed(_:)), for: .touchUpInside)
    }
    
    func setupPlayAllItemsButton() {
        refreshButtonState()
        playAllItemsButton.action = #selector(AudioTourViewController.playAllItems(_:))
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
    
    internal override func audioPlayerChangeNotification(_ notification: Notification) {
        super.audioPlayerChangeNotification(notification)
        refreshButtonState()
    }
    
    @objc func playAllItems(_ sender: AnyObject?) {
        if BRCAudioPlayer.sharedInstance.player != nil {
            BRCAudioPlayer.sharedInstance.togglePlayPause()
        } else {
            if let objects = self.sections.first?.objects {
                BRCAudioPlayer.sharedInstance.playAudioTour(objects as! [BRCArtObject])
            }
        }
        refreshButtonState()
    }

    override func refreshTableItems(_ completion: @escaping ()->()) {
        var art: [BRCArtObject] = []
        BRCDatabaseManager.shared.backgroundReadConnection.asyncRead({ (transaction: YapDatabaseReadTransaction) -> Void in
            if let viewTransaction = transaction.ext(self.extensionName) as? YapDatabaseViewTransaction {
                viewTransaction.enumerateGroups({ (group, stop) -> Void in
                    viewTransaction.enumerateKeysAndObjects(inGroup: group, with: [], using: { (collection: String, key: String, object: Any, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) in
                        if let dataObject = object as? BRCArtObject {
                            art.append(dataObject)
                        }
                    })
                })
            }
            }, completionBlock: { () -> Void in
                NSLog("Audio Tour count: %d", art.count)
                BRCDataSorter.sortDataObjects(art, options: nil, completionQueue: DispatchQueue.main, callbackBlock: { (events, art, camps) -> (Void) in
                    self.processSortedData(events, art: art, camps: camps, completion: completion)
                })
        })
    }

}

private extension AudioTourViewController {
    @objc func soundcloudButtonPressed(_ sender: Any) {
        let url = URL(string: "https://soundcloud.com/burningman/sets/audio-art-tour-2019")!
        WebViewHelper.presentWebView(url: url, from: self)
    }
}
