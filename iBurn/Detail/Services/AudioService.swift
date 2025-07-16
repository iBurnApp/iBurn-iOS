//
//  AudioService.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Concrete implementation of AudioServiceProtocol that wraps BRCAudioPlayer
class AudioService: AudioServiceProtocol {
    private let audioPlayer = BRCAudioPlayer.sharedInstance
    
    func playAudio(artObjects: [BRCArtObject]) {
        audioPlayer.playAudioTour(artObjects)
    }
    
    func pauseAudio() {
        audioPlayer.togglePlayPause()
    }
    
    func isPlaying(artObject: BRCArtObject) -> Bool {
        return audioPlayer.isPlaying(artObject)
    }
    
    func togglePlayPause() {
        audioPlayer.togglePlayPause()
    }
}