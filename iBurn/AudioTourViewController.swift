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
    let introButton = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayAllItemsButton()
        setupIntroButton()
        setupSoundcloudButton()
        setupHeaderView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.refreshButtonState()
    }
    
    func setupIntroButton() {
        introButton.setTitleColor(.label, for: .normal)
        introButton.setTitle("Play Audio Tour Introduction", for: .normal)
        introButton.addTarget(self, action: #selector(introButtonPressed(_:)), for: .touchUpInside)
    }
    
    func setupSoundcloudButton() {
        soundcloudButton.setTitleColor(.label, for: .normal)
        soundcloudButton.setTitle("Open in SoundCloud", for: .normal)
        soundcloudButton.addTarget(self, action: #selector(soundcloudButtonPressed(_:)), for: .touchUpInside)
    }
    
    func setupHeaderView() {
        let stackView = UIStackView(arrangedSubviews: [introButton, soundcloudButton])
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 108)
        tableView.tableHeaderView = stackView
    }
    
    func setupPlayAllItemsButton() {
        refreshButtonState()
        playAllItemsButton.action = #selector(AudioTourViewController.playAllItems(_:))
        playAllItemsButton.target = self
        self.navigationItem.rightBarButtonItem = playAllItemsButton
    }
    
    func refreshButtonState() {
        let isIntroPlaying = isCurrentlyPlayingIntro()
        
        if let player = BRCAudioPlayer.sharedInstance.player {
            if player.rate > 0 {
                if isIntroPlaying {
                    introButton.setTitle("Pause Introduction", for: .normal)
                    playAllItemsButton.title = AudioButtonState.PlayAll.rawValue
                } else {
                    introButton.setTitle("Play Audio Tour Introduction", for: .normal)
                    playAllItemsButton.title = AudioButtonState.Pause.rawValue
                }
            } else {
                if isIntroPlaying {
                    introButton.setTitle("Resume Introduction", for: .normal)
                    playAllItemsButton.title = AudioButtonState.PlayAll.rawValue
                } else {
                    introButton.setTitle("Play Audio Tour Introduction", for: .normal)
                    playAllItemsButton.title = AudioButtonState.Resume.rawValue
                }
            }
        } else {
            playAllItemsButton.title = AudioButtonState.PlayAll.rawValue
            introButton.setTitle("Play Audio Tour Introduction", for: .normal)
        }
    }
    
    /// Check if the intro is currently the active item in the player
    private func isCurrentlyPlayingIntro() -> Bool {
        // Create an intro object to check against
        guard let introArt = BRCArtObject.intro() else {
            return false
        }
        // Use the hasItem method to check if intro is loaded (playing or paused)
        return BRCAudioPlayer.sharedInstance.hasItem(introArt)
    }
    
    internal override func audioPlayerChangeNotification(_ notification: Notification) {
        super.audioPlayerChangeNotification(notification)
        // Just refresh the button state - it will check the actual player state
        refreshButtonState()
    }
    
    @objc func playAllItems(_ sender: AnyObject?) {
        // Check if we're currently playing the intro
        if isCurrentlyPlayingIntro() {
            // Stop intro and start tour
            if let objects = self.sections.first?.objects {
                BRCAudioPlayer.sharedInstance.playAudioTour(objects as! [BRCArtObject])
            }
        } else {
            // Normal toggle behavior
            if BRCAudioPlayer.sharedInstance.player != nil {
                BRCAudioPlayer.sharedInstance.togglePlayPause()
            } else {
                if let objects = self.sections.first?.objects {
                    BRCAudioPlayer.sharedInstance.playAudioTour(objects as! [BRCArtObject])
                }
            }
        }
        refreshButtonState()
    }

    override func refreshTableItems(_ completion: @escaping ()->()) {
        var art: [BRCArtObject] = []
        BRCDatabaseManager.shared.backgroundReadConnection.asyncRead({ (transaction: YapDatabaseReadTransaction) -> Void in
            if let viewTransaction = transaction.ext(self.extensionName) as? YapDatabaseViewTransaction {
                viewTransaction.enumerateGroups({ (group, stop) -> Void in
                    viewTransaction.iterateKeysAndObjects(inGroup: group) { (collection, key, object, index, stop) in
                        if let dataObject = object as? BRCArtObject {
                            art.append(dataObject)
                        }
                    }
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
    @objc func introButtonPressed(_ sender: Any) {
        playIntroAudio()
    }
    
    @objc func soundcloudButtonPressed(_ sender: Any) {
        let url = URL(string: "https://m.soundcloud.com/burningman/sets")!
        WebViewHelper.presentWebView(url: url, from: self)
    }
    
    func playIntroAudio() {
        // Create the intro object using the factory method
        guard let introArt = BRCArtObject.intro() else {
            print("Could not create intro BRCArtObject")
            return
        }
        
        // Check if intro is currently loaded (playing or paused)
        if BRCAudioPlayer.sharedInstance.hasItem(introArt) {
            // Toggle play/pause for the intro
            BRCAudioPlayer.sharedInstance.togglePlayPause()
        } else {
            // Play the intro (will stop any other audio)
            BRCAudioPlayer.sharedInstance.playAudioTour([introArt])
        }
        refreshButtonState()
    }
}
