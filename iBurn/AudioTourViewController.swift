//
//  AudioTourViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase
import AVFoundation
import MediaPlayer

enum AudioButtonState: String {
    case PlayAll = "Play All"
    case Resume = "Resume"
    case Pause = "Pause"
}

class AudioTourViewController: SortedViewController {
    
    let playAllItemsButton = UIBarButtonItem()
    let soundcloudButton = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    let introButton = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    private var isPlayingIntro = false
    
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
        if let player = BRCAudioPlayer.sharedInstance.player {
            if player.rate > 0 {
                if isPlayingIntro {
                    introButton.setTitle("Pause Introduction", for: .normal)
                } else {
                    playAllItemsButton.title = AudioButtonState.Pause.rawValue
                }
            } else {
                if isPlayingIntro {
                    introButton.setTitle("Resume Introduction", for: .normal)
                } else {
                    playAllItemsButton.title = AudioButtonState.Resume.rawValue
                }
            }
        } else {
            playAllItemsButton.title = AudioButtonState.PlayAll.rawValue
            introButton.setTitle("Play Audio Tour Introduction", for: .normal)
            isPlayingIntro = false
        }
    }
    
    internal override func audioPlayerChangeNotification(_ notification: Notification) {
        super.audioPlayerChangeNotification(notification)
        // Reset intro state if player was reset
        if BRCAudioPlayer.sharedInstance.player == nil {
            isPlayingIntro = false
        }
        refreshButtonState()
    }
    
    @objc func playAllItems(_ sender: AnyObject?) {
        // Reset intro playing state when playing all items
        isPlayingIntro = false
        
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
        let url = URL(string: "https://soundcloud.com/burningman/sets/2024-art-audio-guide")!
        WebViewHelper.presentWebView(url: url, from: self)
    }
    
    func playIntroAudio() {
        // Check if intro.m4a exists in the MediaFiles bundle
        guard let introURL = getIntroAudioURL() else {
            print("Could not find intro.m4a in MediaFiles bundle")
            return
        }
        
        // If currently playing intro, toggle play/pause
        if isPlayingIntro, BRCAudioPlayer.sharedInstance.player != nil {
            BRCAudioPlayer.sharedInstance.togglePlayPause()
        } else {
            // Reset any existing playback
            if BRCAudioPlayer.sharedInstance.player != nil {
                BRCAudioPlayer.sharedInstance.playAudioTour([])
            }
            
            // Create a simple AVQueuePlayer for the intro
            let introItem = AVPlayerItem(url: introURL)
            let player = AVQueuePlayer(items: [introItem])
            
            // Set the player directly on BRCAudioPlayer
            BRCAudioPlayer.sharedInstance.player = player
            
            // Start playback
            isPlayingIntro = true
            BRCAudioPlayer.sharedInstance.play()
            
            // Update Now Playing info
            var nowPlayingInfo = [String : Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = "Audio Tour Introduction"
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Burning Man"
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Burning Man Audio Tour"
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        refreshButtonState()
    }
    
    func getIntroAudioURL() -> URL? {
        // Try to get intro.m4a from the MediaFiles bundle
        if let url = Bundle.brc_mediaFileURL(fileId: "intro", extension: "m4a") {
            return url
        }
        
        // Fallback: try direct bundle access
        if let mediaBundle = Bundle.bundledMedia {
            return mediaBundle.url(forResource: "intro", withExtension: "m4a")
        }
        
        return nil
    }
}
