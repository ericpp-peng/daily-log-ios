//
//  VideoPlayerManager.swift
//  daily-log-ios
//
//  Multi-clip timeline player. Mirrors VideoEditorKit's
//  `VideoPlayerManager` role (own AVPlayer + preview coordination)
//  but Daily Log composes many clips, so this manager also handles
//  clip-to-clip advancement and per-clip kind (video vs photo).
//

import AVFoundation
import Combine
import Observation
import SwiftUI

@MainActor
@Observable
final class VideoPlayerManager {
    // MARK: - Public state

    private(set) var items: [TimelineItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var globalTime: TimeInterval = 0
    private(set) var currentImage: UIImage?
    private(set) var isLoadingClip: Bool = false

    let player: AVPlayer = AVPlayer()

    // MARK: - Derived state

    var currentItem: TimelineItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var totalDuration: TimeInterval {
        items.reduce(0) { $0 + $1.effectiveDuration }
    }

    var globalProgress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(globalTime / totalDuration, 0), 1)
    }

    // MARK: - Internal

    private var cumulativeStartTimes: [TimeInterval] = []
    private var photoTimerTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?
    private var loadGeneration: Int = 0

    init() {
        configureAudioSession()
        configurePlayerObservers()
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    // MARK: - Public API

    func load(items: [TimelineItem]) {
        self.items = items
        recomputeCumulativeStarts()
        currentIndex = 0
        globalTime = 0
        Task { await activateCurrentClip(resetSeek: true) }
    }

    func update(items: [TimelineItem]) {
        let previousId = currentItem?.id
        self.items = items
        recomputeCumulativeStarts()

        if let previousId, let index = items.firstIndex(where: { $0.id == previousId }) {
            currentIndex = index
        } else {
            currentIndex = min(currentIndex, max(items.count - 1, 0))
            Task { await activateCurrentClip(resetSeek: true) }
        }
    }

    func play() {
        guard !items.isEmpty else { return }
        isPlaying = true
        if currentItem?.usesVideoPlayback == true {
            player.play()
        } else {
            startPhotoTimerIfNeeded()
        }
    }

    func pause() {
        isPlaying = false
        player.pause()
        photoTimerTask?.cancel()
        photoTimerTask = nil
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func selectItem(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        currentIndex = index
        globalTime = cumulativeStartTimes[safe: index] ?? 0
        Task { await activateCurrentClip(resetSeek: true) }
    }

    func seek(toGlobal seconds: TimeInterval) {
        let clamped = min(max(seconds, 0), totalDuration)
        globalTime = clamped

        guard let (index, localTime) = clipIndex(forGlobal: clamped) else { return }
        if index != currentIndex {
            currentIndex = index
            Task { await activateCurrentClip(resetSeek: false, localSeek: localTime) }
        } else if currentItem?.usesVideoPlayback == true {
            let cmTime = CMTime(seconds: localTime + (currentItem?.configuration.trim.lowerBound ?? 0),
                                preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    // MARK: - Activation

    private func activateCurrentClip(resetSeek: Bool, localSeek: TimeInterval = 0) async {
        photoTimerTask?.cancel()
        photoTimerTask = nil

        guard let item = currentItem else {
            player.replaceCurrentItem(with: nil)
            currentImage = nil
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        isLoadingClip = true

        if resetSeek {
            globalTime = cumulativeStartTimes[safe: currentIndex] ?? 0
        }

        if item.usesVideoPlayback {
            currentImage = nil
            let asset = await PhotoLibraryService.shared.requestAVAsset(for: item.asset)
            guard generation == loadGeneration else { return }
            if let asset {
                let playerItem = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: playerItem)
                let startCM = CMTime(seconds: item.configuration.trim.lowerBound + localSeek,
                                     preferredTimescale: 600)
                await player.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero)
                if isPlaying { player.play() }
            } else {
                player.replaceCurrentItem(with: nil)
            }
        } else {
            player.replaceCurrentItem(with: nil)
            let image = await PhotoLibraryService.shared.requestPreviewImage(
                for: item.asset,
                targetSize: CGSize(width: 1080, height: 1920)
            )
            guard generation == loadGeneration else { return }
            currentImage = image
            if isPlaying { startPhotoTimerIfNeeded(remainingOverride: max(item.effectiveDuration - localSeek, 0)) }
        }

        isLoadingClip = false
    }

    // MARK: - Advancement

    private func advanceToNextClip() {
        guard isPlaying, !isLoadingClip else { return }

        photoTimerTask?.cancel()
        photoTimerTask = nil

        guard currentIndex + 1 < items.count else {
            resetCurrentClipToStartAfterPlayback()
            return
        }
        isLoadingClip = true
        currentIndex += 1
        globalTime = cumulativeStartTimes[safe: currentIndex] ?? 0
        Task { await activateCurrentClip(resetSeek: true) }
    }

    private func resetCurrentClipToStartAfterPlayback() {
        pause()

        let startTime = cumulativeStartTimes[safe: currentIndex] ?? 0
        globalTime = startTime

        guard let item = currentItem, item.usesVideoPlayback else { return }
        let trimStart = CMTime(seconds: item.configuration.trim.lowerBound, preferredTimescale: 600)
        player.seek(to: trimStart, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func startPhotoTimerIfNeeded(remainingOverride: TimeInterval? = nil) {
        guard let item = currentItem, !item.usesVideoPlayback else { return }
        let duration = remainingOverride ?? item.effectiveDuration
        guard duration > 0 else { advanceToNextClip(); return }

        let generation = loadGeneration
        photoTimerTask = Task { [weak self] in
            let start = Date()
            let nanos = UInt64(duration * 1_000_000_000)
            let step: UInt64 = 50_000_000 // 50 ms tick for smooth progress
            var elapsed: UInt64 = 0
            while elapsed < nanos {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: min(step, nanos - elapsed))
                elapsed += step
                await MainActor.run {
                    guard let self else { return }
                    if generation != self.loadGeneration { return }
                    let real = min(Date().timeIntervalSince(start), duration)
                    let base = self.cumulativeStartTimes[safe: self.currentIndex] ?? 0
                    self.globalTime = base + real
                }
            }
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self, generation == self.loadGeneration else { return }
                self.advanceToNextClip()
            }
        }
    }

    // MARK: - Player observers

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Keep playback usable even if the audio session cannot be promoted.
        }
    }

    private func configurePlayerObservers() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      self.isPlaying,
                      !self.isLoadingClip,
                      let endedItem = notification.object as? AVPlayerItem,
                      endedItem === self.player.currentItem else {
                    return
                }
                self.advanceToNextClip()
            }
        }

        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self,
                      self.isPlaying,
                      !self.isLoadingClip,
                      let item = self.currentItem,
                      item.usesVideoPlayback else { return }
                let local = max(0, time.seconds - item.configuration.trim.lowerBound)
                let base = self.cumulativeStartTimes[safe: self.currentIndex] ?? 0
                self.globalTime = base + min(local, item.effectiveDuration)

                // Manual end-of-trim detection (we trim shorter than the asset).
                if time.seconds >= item.configuration.trim.upperBound - 0.02 {
                    self.advanceToNextClip()
                }
            }
        }
    }

    // MARK: - Helpers

    private func recomputeCumulativeStarts() {
        var cumulative: [TimeInterval] = []
        var running: TimeInterval = 0
        for item in items {
            cumulative.append(running)
            running += item.effectiveDuration
        }
        cumulativeStartTimes = cumulative
    }

    private func clipIndex(forGlobal seconds: TimeInterval) -> (Int, TimeInterval)? {
        guard !items.isEmpty else { return nil }
        for (index, item) in items.enumerated() {
            let start = cumulativeStartTimes[safe: index] ?? 0
            let end = start + item.effectiveDuration
            if seconds < end || index == items.count - 1 {
                return (index, max(0, seconds - start))
            }
        }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
