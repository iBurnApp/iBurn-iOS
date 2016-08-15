//
//  BRCAudioPlayer.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/5/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import Foundation
import AVFoundation

/** Make sure to listen for BRCAudioPlayerChangeNotification and refresh your views */
public class BRCAudioPlayer: NSObject {
    /** This is fired if track is changed, or stops playing */
    public static let BRCAudioPlayerChangeNotification = "BRCAudioPlayerChangeNotification"
    public static let sharedInstance = BRCAudioPlayer()
    var player: AVQueuePlayer?
    private var nowPlaying: BRCArtObject?
    private var queuedObjects: [BRCArtObject] = []
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
    }
    
    public override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(BRCAudioPlayer.didFinishPlaying(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
    }
    
    public func isPlaying(item: BRCArtObject) -> Bool {
        if nowPlaying?.uniqueID == item.uniqueID && player?.rate > 0 {
            return true
        }
        return false
    }
    
    /** Plays audio tour for items, if they are the same it will pause */
    public func playAudioTour(items: [BRCArtObject]) {
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
                let playerItem = AVPlayerItem(URL: url)
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
    
    public func togglePlayPause() {
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
    
    private func fireChangeNotification() {
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(BRCAudioPlayer.BRCAudioPlayerChangeNotification, object: self)
        }
    }
    
    private func reset() {
        nowPlaying = nil
        queuedObjects = []
        player?.removeAllItems()
        player = nil
    }
    
    func didFinishPlaying(notification: NSNotification) {
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
                    if object.audioURL == asset.URL {
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