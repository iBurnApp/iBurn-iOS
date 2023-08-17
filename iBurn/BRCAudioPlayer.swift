//
//  BRCAudioPlayer.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/5/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

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
public final class BRCAudioPlayer: NSObject {
    /** This is fired if track is changed, or stops playing */
    @objc public static let BRCAudioPlayerChangeNotification = "BRCAudioPlayerChangeNotification"
    @objc public static let sharedInstance = BRCAudioPlayer()
    var player: AVQueuePlayer? {
        didSet {
            if let player {
                itemObserver = player.observe(\.currentItem, options: .initial) {
                    [weak self] _, _ in
                    self?.handlePlayerItemChange()
                }
                rateObserver = player.observe(\.rate, options: .initial) {
                    [weak self] _, _ in
                    self?.handlePlaybackChange()
                }
                statusObserver = player.observe(\.currentItem?.status, options: .initial) {
                    [weak self] _, _ in
                    self?.handlePlaybackChange()
                }
            }
        }
    }
    fileprivate var nowPlaying: BRCArtObject? {
        didSet {
            handlePlayerItemChange()
        }
    }
    fileprivate var queuedObjects: [BRCArtObject] = []
    private var itemObserver: NSKeyValueObservation!
    private var rateObserver: NSKeyValueObservation!
    private var statusObserver: NSObjectProtocol!
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(BRCAudioPlayer.didFinishPlayingNotification(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        setupRemoteTransportControls()
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
        }
    }
    
    func teardownAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error tearing down audio session: \(error)")
        }
    }
    
    @objc public func isPlaying(_ item: BRCArtObject) -> Bool {
        if nowPlaying?.uniqueID == item.uniqueID && player?.rate > 0 {
            return true
        }
        return false
    }
    
    /** Plays audio tour for items, if they are the same it will pause */
    @objc public func playAudioTour(_ items: [BRCArtObject]) {
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
            play()
            nowPlaying = items.first
        } else {
            reset()
        }
        fireChangeNotification()
    }
    
    @objc public func togglePlayPause() {
        if ((player?.currentItem) == nil) {
            reset()
        } else {
            if player?.rate > 0 {
                pause()
            } else {
                play()
            }
        }
        fireChangeNotification()
    }
    
    fileprivate func fireChangeNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification), object: self)
        }
    }
    
    @discardableResult
    func play() -> Bool {
        setupAudioSession()
        enableRemoteTransportControls()
        if let player, player.rate == 0.0 {
            player.play()
            return true
        }
        return false
    }
    
    @discardableResult
    func pause() -> Bool {
        defer {
            teardownAudioSession()
        }
        if let player, player.rate > 0 {
            player.pause()
            return true
        }
        return false
    }
    
    fileprivate func reset() {
        nowPlaying = nil
        queuedObjects = []
        player?.removeAllItems()
        player = nil
        teardownAudioSession()
        disableRemoteTransportControls()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] event in
            if self?.play() == true {
                return .success
            } else {
                return .commandFailed
            }
        }
        commandCenter.pauseCommand.addTarget { [weak self] event in
            if self?.pause() == true {
                return .success
            } else {
                return .commandFailed
            }
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.player?.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero) {
                isFinished in
                if isFinished {
                    self?.handlePlaybackChange()
                }
            }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.player?.currentItem.flatMap { self?.didFinishPlaying($0) }
            self?.player?.advanceToNextItem()
            return .success
        }
    }
    
    func enableRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
    }
    
    func disableRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
    }
    
    func handlePlayerItemChange() {
        if let nowPlaying {
            var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String : Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlaying.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = nowPlaying.artistName
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Burning Man 2023 Audio Tour"
            // we could do better with these calculations
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = queuedObjects.count
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = 1
            // it would be better to load these off of the main thread
            if let localThumbnailURL = nowPlaying.localThumbnailURL,
               let image = UIImage(contentsOfFile: localThumbnailURL.path) {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { size in
                    if #available(iOS 15.0, *) {
                        return image.preparingThumbnail(of: size) ?? image
                    } else {
                        return image
                    }
                })
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
    
    func handlePlaybackChange() {
        if let player {
            var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String : Any]()
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
            if let currentItem = player.currentItem {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(currentItem.currentTime().seconds)
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(currentItem.duration.seconds)
            }
            nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    @objc func didFinishPlayingNotification(_ notification: Notification) {
        let endedItem = notification.object as? AVPlayerItem
        endedItem.flatMap { didFinishPlaying($0) }
    }
    
    private func didFinishPlaying(_ endedItem: AVPlayerItem) {
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
