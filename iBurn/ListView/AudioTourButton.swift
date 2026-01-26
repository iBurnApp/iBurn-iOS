//
//  AudioTourButton.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import SwiftUI

protocol AudioPlayerProtocol: AnyObject {
    func playAudioTour(_ tracks: [BRCAudioTourTrack])
    func isPlaying(id: String) -> Bool
}

extension BRCAudioPlayer: AudioPlayerProtocol {}

struct AudioTourButton: View {
    let track: BRCAudioTourTrack
    let audioPlayer: any AudioPlayerProtocol

    @State private var isPlaying = false

    var body: some View {
        Button {
            audioPlayer.playAudioTour([track])
            isPlaying = audioPlayer.isPlaying(id: track.uid)
        } label: {
            Text(isPlaying ? "🔊 ⏸" : "🔈 ▶️")
                .font(.subheadline)
        }
        .buttonStyle(.plain)
        .onAppear {
            isPlaying = audioPlayer.isPlaying(id: track.uid)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification)
            )
        ) { _ in
            isPlaying = audioPlayer.isPlaying(id: track.uid)
        }
    }
}

