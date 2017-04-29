//
//  BRCAudioPlayer.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/5/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import Foundation
import AVFoundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


/** Make sure to listen for BRCAudioPlayerChangeNotification and refresh your views */
open class BRCAudioPlayer: NSObject {
    /** This is fired if track is changed, or stops playing */
    open static let BRCAudioPlayerChangeNotification = "BRCAudioPlayerChangeNotification"
    open static let sharedInstance = BRCAudioPlayer()
    var player: AVQueuePlayer?
    fileprivate var nowPlaying: BRCArtObject?
    fileprivate var queuedObjects: [BRCArtObject] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(BRCAudioPlayer.didFinishPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    open func isPlaying(_ item: BRCArtObject) -> Bool {
        if nowPlaying?.uniqueID == item.uniqueID && player?.rate > 0 {
            return true
        }
        return false
    }
    
    /** Plays audio tour for items, if they are the same it will pause */
    open func playAudioTour(_ items: [BRCArtObject]) {
        // this should never happen
        if items.count == 0 {
            reset()
            fireChangeNotification()
            return
        }
        if items == queuedObjects {
            togglePlayPause()
            return
        }
        if nowPlaying?.uniqueID == items.first?.uniqueID {
            togglePlayPause()
            return
        }
        queuedObjects = items
        var playerItems: [AVPlayerItem] = []
        for item in items {
            if let url = item.audioURL {
                let playerItem = AVPlayerItem(url: url)
                playerItems.append(playerItem)
            }
        }
        if items.count > 0 {
            player = AVQueuePlayer(items: playerItems)
            player?.play()
            nowPlaying = items.first
        } else {
            reset()
        }
        fireChangeNotification()
    }
    
    open func togglePlayPause() {
        if ((player?.currentItem) == nil) {
            reset()
        } else {
            if player?.rate > 0 {
                player?.pause()
            } else {
                player?.play()
            }
        }
        fireChangeNotification()
    }
    
    fileprivate func fireChangeNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification), object: self)
        }
    }
    
    fileprivate func reset() {
        nowPlaying = nil
        queuedObjects = []
        player?.removeAllItems()
        player = nil
    }
    
    func didFinishPlaying(_ notification: Notification) {
        let endedItem = notification.object as? AVPlayerItem
                
        if (player?.items().count == 0) {
            reset()
        }
        if ((player?.currentItem) == nil) {
            reset()
        }
        if (player?.items().count == 1 && player?.currentItem == endedItem) {
            reset()
        } else if (player?.items().count > 1) {
            // Not the best way to find nowPlaying..
            if let asset = player?.items()[1].asset as? AVURLAsset {
                for object in queuedObjects {
                    if object.audioURL == asset.url {
                        nowPlaying = object
                        break
                    }
                }
            } else {
                reset()
            }
        }
        

        fireChangeNotification()
    }
}
