//
//  VideoPlayerLayerView.swift
//  daily-log-ios
//
//  SwiftUI bridge to AVPlayerLayer. VideoEditorKit avoids UIKit
//  imports because it ships as a portable Swift Package; Daily Log
//  is an app target, so a tiny UIKit-backed AVPlayerLayer host
//  remains the cleanest way to render frames without bringing in
//  AVKit's native player controls.
//

import AVFoundation
import SwiftUI
import UIKit

struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
