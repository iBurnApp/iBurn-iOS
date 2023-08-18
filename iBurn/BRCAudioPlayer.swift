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
    private var itemObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var interruptionObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(BRCAudioPlayer.didFinishPlayingNotification(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                      object: AVAudioSession.sharedInstance(),
                                                                      queue: .main) {
            [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
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
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            return self?.goBack() ?? .noSuchContent
        }
    }
    
    func enableRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = queuedObjects.count > 1
        commandCenter.previousTrackCommand.isEnabled = true
    }
    
    func disableRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
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
            
            if let playerItem = player?.currentItem {
                var allItems: [AVMetadataItem] = []
                if let metadata = self.metadataItem(identifier: .commonIdentifierTitle, value: nowPlaying.title as NSString) {
                    allItems.append(metadata)
                }
                // https://stackoverflow.com/a/41837833
                var description = nowPlaying.detailDescription ?? " "
                if description.isEmpty {
                    description = " "
                }
                if let metadata = self.metadataItem(identifier: .commonIdentifierDescription, value: description as NSString) {
                    allItems.append(metadata)
                }
                
                if let localThumbnailURL = nowPlaying.localThumbnailURL,
                   let jpegData = try? Data(contentsOf: localThumbnailURL),
                   let artworkItem = self.metadataArtworkItem(jepgData: jpegData) {
                    allItems.append(artworkItem)
                }
                
                playerItem.externalMetadata = allItems
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
    
    private func goBack() -> MPRemoteCommandHandlerStatus{
        var currentIndex = -1
        for (i, item) in queuedObjects.enumerated() {
            guard let asset = player?.currentItem?.asset as? AVURLAsset else {
                continue
            }
            if item.audioURL == asset.url {
                currentIndex = i
                break
            }
        }
        if let currentDuration = player?.currentItem?.currentTime(), currentDuration.seconds > 4 || queuedObjects.count == 1 {
            restartCurrentTrack()
            return .success
        }
        if currentIndex == 0 {
            currentIndex = queuedObjects.count
        }
        guard let newURL = queuedObjects[currentIndex - 1].audioURL,
              let currentItem = player?.currentItem else {
            return .noSuchContent
        }
        let newItem = AVPlayerItem(url: newURL)
        player?.replaceCurrentItem(with: newItem)
        player?.insert(currentItem, after: newItem)
        nowPlaying = queuedObjects[currentIndex - 1]
        restartCurrentTrack()
        return .success
    }
    
    func restartCurrentTrack() {
        player?.seek(to: CMTime(seconds: 0, preferredTimescale: 1)) { finished in
            if finished {
                self.handlePlaybackChange()
            }
        }
    }
}

// https://stackoverflow.com/q/41557731
private extension BRCAudioPlayer {
    func metadataItem(identifier: AVMetadataIdentifier, value: (NSCopying & NSObjectProtocol)?) -> AVMetadataItem? {
        if let actualValue = value {
            let item = AVMutableMetadataItem()
            item.value = actualValue
            item.identifier = identifier
            item.extendedLanguageTag = "und"
            return item.copy() as? AVMetadataItem
        }
        return nil
    }
    
    func metadataArtworkItem(jepgData: Data) -> AVMetadataItem? {
        let item = AVMutableMetadataItem()
        item.value = jepgData as NSData
        item.dataType = kCMMetadataBaseDataType_JPEG as String
        item.identifier = .commonIdentifierArtwork
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
    }
    
    private func handleAudioSessionInterruption(notification: Notification) {
        // Retrieve the interruption type from the notification.
        guard let userInfo = notification.userInfo,
              let interruptionTypeUInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeUInt) else { return }
        
        // Begin or end an interruption.
        
        switch interruptionType {
        case .began:
            break
        case .ended:
            // When an interruption ends, determine whether playback should resume
            // automatically, and reactivate the audio session if necessary.
            
            do {
                
                try AVAudioSession.sharedInstance().setActive(true)
                
                var shouldResume = false
                
                if let optionsUInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                   AVAudioSession.InterruptionOptions(rawValue: optionsUInt).contains(.shouldResume) {
                    shouldResume = true
                }
                if shouldResume {
                    play()
                }
            }
            
            // When the audio session cannot be resumed after an interruption,
            // invoke the handler with error information.
            
            catch {
                print("Could not resume audio session: \(error)")
            }
            
        @unknown default:
            break
        }
    }
}

