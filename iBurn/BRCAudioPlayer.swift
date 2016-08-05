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
    var player: AVPlayer?
    private var nowPlaying: BRCArtObject?
    
    public func isPlaying(item: BRCArtObject) -> Bool {
        if nowPlaying?.uniqueID == item.uniqueID && player?.rate > 0 {
            return true
        }
        return false
    }
    
    public func playAudioTour(item: BRCArtObject) {
        if nowPlaying?.uniqueID == item.uniqueID {
            if player?.rate > 0 {
                player?.pause()
            } else {
                player?.play()
            }
            return
        }
        if let url = item.audioURL {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
            let playerItem = AVPlayerItem(URL: url)
            player = AVPlayer(playerItem: playerItem)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(BRCAudioPlayer.didFinishPlaying(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
            player?.play()
            nowPlaying = item
        } else {
            nowPlaying = nil
            player = nil
        }
        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(BRCAudioPlayer.BRCAudioPlayerChangeNotification, object: self)
        }
    }
    
    func didFinishPlaying(notification: NSNotification) {
        nowPlaying = nil
        player = nil
        dispatch_async(dispatch_get_main_queue()) { 
            NSNotificationCenter.defaultCenter().postNotificationName(BRCAudioPlayer.BRCAudioPlayerChangeNotification, object: self)
        }
    }
}