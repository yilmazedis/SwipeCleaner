//
//  VideoPlayerView.swift
//  SwipeCleaner
//
//  Created by Yılmaz Edis on 14.03.2026.
//


import SwiftUI
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating // shows play/pause, timeline etc.
        playerView.autoresizingMask = [.width, .height]
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let player = AVPlayer(url: fileURL)
        nsView.player = player
        player.play() // auto‑play; you can change this behavior
    }
}