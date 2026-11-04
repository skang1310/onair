import Foundation
import AVFoundation
import Network
import MediaPlayer
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
#if os(iOS)
@preconcurrency import ActivityKit
import UIKit
#endif

@MainActor @Observable final class RadioPlayer {
    static let shared = RadioPlayer()
    var station: Station?
    var audioOutput = RadioAudioOutput(name: "출력 확인 중", symbol: "speaker.wave.2")
    var volume: Float = 1 { didSet { player.volume = max(0, min(1, volume)) * sleepFade } }
    #if os(iOS)
    private var nowPlayingArtworkKey: String?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    #endif
    private var sleepFade: Float = 1
    var isPlaying = false
    var buffering = false
    var error: String?
    var sleepEnd: Date?
    var reconnectAttempt = 0
    var connectionLabel: String { error != nil ? "연결 실패" : reconnectAttempt > 0 && buffering ? "다시 연결 중 · \(reconnectAttempt)/3" : buffering ? "연결 중" : isPlaying ? "생방송" : "일시정지" }
    #if DEBUG
    var backgroundPlaybackVerified = false
    func verifyBackgroundPlayback() {
        let token = generation
        let initial = player.currentTime().seconds
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, self.generation == token else { return }
            self.backgroundPlaybackVerified = self.player.rate > 0 && self.player.currentTime().seconds > initial + 10
        }
    }
    #endif
    private var reconnectTask: Task<Void, Never>?
    private let networkMonitor = NWPathMonitor()
    private var waitingForNetwork = false
    private var stalledObserver: NSObjectProtocol?
    private let player = AVPlayer()
    private var statusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var timerTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?
    private var generation = 0
    private var desiredPlayback = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private var resumeAfterInterruption = false
    private init() {
        station = SharedStore.read().station.flatMap { $0.isEligible ? $0 : nil }
        player.automaticallyWaitsToMinimizeStalling = true
        playbackObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let status = self.player.timeControlStatus
                self.buffering = self.desiredPlayback && status != .playing && self.error == nil
                self.isPlaying = status == .playing
                if self.isPlaying { self.reconnectAttempt = 0; self.timeoutTask?.cancel(); if let station = self.station { RecentListening.shared.record(station) } }
                self.publish()
            }
        }
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                if !available { self.waitingForNetwork = true }
                else if self.waitingForNetwork {
                    self.waitingForNetwork = false
                    if self.desiredPlayback && !self.isPlaying { self.reconnect(reason: "네트워크를 다시 연결합니다") }
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "onair.network"))
        stalledObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, self.desiredPlayback else { return }; self.armTimeout() }
        }
        MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }; return .success
        }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }; return .success
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    let shouldResume = self.desiredPlayback
                    self.pause()
                    self.resumeAfterInterruption = shouldResume
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    let shouldResume = self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.resumeAfterInterruption = false
                    if shouldResume { self.resume() }
                }
            }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                self.refreshAudioOutput()
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { self.pause() }
                else { self.publish() }
            }
        }
        refreshAudioOutput()
        publish() // A relaunched process has no active audio; clear stale widget playback state.
        #if os(iOS)
        clearLegacyActivities()
        #endif
    }
    func play(_ value: Station) {
        guard value.isEligible, value.streamURL != nil else { error = "방송 주소가 없어요. 다른 방송국을 선택해 주세요."; return }
        pause(); reconnectAttempt = 0; station = value; error = nil; desiredPlayback = true; buffering = true; beginConnection()
    }
    private func beginConnection() {
        guard let value = station else { return }; publish()
        let token = generation
        resolveTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await StreamResolver.resolve(value)
                guard !Task.isCancelled, self.generation == token else { return }
                #if os(watchOS)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
                AVAudioSession.sharedInstance().activate(options: []) { [weak self] success, _ in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        if success { self.load(url) }
                        else { self.desiredPlayback = false; self.buffering = false; self.error = "오디오 출력을 연결한 뒤 다시 시도해 주세요." }
                    }
                }
                #else
                try await Task.detached {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
                    try session.setActive(true, options: [])
                }.value
                guard !Task.isCancelled, self.generation == token else { return }
                self.load(url)
                #endif
            } catch {
                guard !Task.isCancelled, self.generation == token else { return }
                self.reconnect(reason: "최신 방송 주소를 받지 못했어요.")
            }
        }
    }
    private func load(_ url: URL) {
        let item = AVPlayerItem(url: url)
        let token = generation
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            Task { @MainActor [weak self] in
                if failed, self?.generation == token { self?.reconnect(reason: "방송 연결이 끊겼어요.") }
            }
        }
        player.replaceCurrentItem(with: item); player.play(); publish()
        armTimeout()
    }
    private func armTimeout() {
        timeoutTask?.cancel()
        let token = generation
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled, let self, self.generation == token, self.desiredPlayback, !self.isPlaying else { return }
            self.reconnect(reason: "방송 서버 응답이 늦어요.")
        }
    }
    private func reconnect(reason: String) {
        guard desiredPlayback, reconnectTask == nil else { return }
        guard let delay = ReconnectPolicy.delay(for: reconnectAttempt) else {
            pause(); error = "\(reason) 자동 연결을 3회 시도했어요. 다시 재생하거나 다른 방송을 선택해 주세요."; publish(); return
        }
        reconnectAttempt += 1; generation += 1; resolveTask?.cancel(); timeoutTask?.cancel()
        statusObservation = nil; player.replaceCurrentItem(with: nil); isPlaying = false; buffering = true; publish()
        let token = generation
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.generation == token, self.desiredPlayback else { return }
            self.reconnectTask = nil; self.beginConnection()
        }
    }
    func toggle() { if isPlaying || buffering { pause() } else { resume() } }
    func resume() {
        guard let station else { return }
        play(station)
    }
    func pause() {
        resumeAfterInterruption = false
        generation += 1; reconnectTask?.cancel(); reconnectTask = nil; desiredPlayback = false; resolveTask?.cancel(); timeoutTask?.cancel(); player.pause(); isPlaying = false; buffering = false; publish()
    }
    static func sleepFadeFactor(remaining: TimeInterval) -> Float { Float(max(0, min(1, remaining / 30))) }
    func setSleep(minutes: Int?) {
        timerTask?.cancel(); sleepFade = 1; player.volume = max(0, min(1, volume))
        guard let minutes, minutes > 0 else { sleepEnd = nil; publish(); return }
        let end = Date.now.addingTimeInterval(Double(minutes * 60)); sleepEnd = end; publish()
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow - 30)))
            while !Task.isCancelled, let self, self.sleepEnd == end {
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 {
                    self.sleepEnd = nil; self.pause(); self.sleepFade = 1; self.player.volume = max(0, min(1, self.volume)); return
                }
                self.sleepFade = Self.sleepFadeFactor(remaining: remaining)
                self.player.volume = max(0, min(1, self.volume)) * self.sleepFade
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
    private func refreshAudioOutput() {
        let ports = AVAudioSession.sharedInstance().currentRoute.outputs
        guard !ports.isEmpty else {
            audioOutput = .init(name: "출력 미연결", symbol: "speaker.slash")
            return
        }
        let names = ports.map { port in
            if port.portType == .builtInSpeaker {
                #if os(watchOS)
                return "Watch 스피커"
                #elseif os(tvOS)
                return "TV 스피커"
                #else
                return "iPhone 스피커"
                #endif
            }
            return port.portName
        }
        let symbol: String
        if ports.contains(where: { $0.portType == .airPlay }) { symbol = "airplay.audio" }
        else if ports.contains(where: { [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .headphones].contains($0.portType) }) { symbol = "headphones" }
        else { symbol = "speaker.wave.2" }
        audioOutput = .init(name: names.joined(separator: " · "), symbol: symbol)
    }
    private func publish() {
        refreshAudioOutput()
        var snapshot = SharedStore.read(); snapshot.station = station; snapshot.isPlaying = isPlaying; snapshot.updatedAt = .now; snapshot.sleepEnd = sleepEnd; snapshot.buffering = buffering; snapshot.audioOutput = audioOutput
        SharedStore.save(snapshot)
        #if !WIDGET_EXTENSION
        DeviceSync.shared.publishPlayback(snapshot)
        #endif
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        if let station {
            var info: [String: Any] = [MPMediaItemPropertyTitle: station.name, MPMediaItemPropertyArtist: "온에어 · 한국 라디오", MPNowPlayingInfoPropertyIsLiveStream: true, MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0]
            #if os(iOS)
            if nowPlayingArtworkKey != station.id {
                // Bundle artwork works offline and stays available when the app is locked.
                let renderer = ImageRenderer(content: StationArtwork(station: station, cornerRadius: 0)
                    .frame(width: 512, height: 512))
                renderer.scale = 1
                if let image = renderer.uiImage {
                    nowPlayingArtwork = Self.makeNowPlayingArtwork(image)
                    nowPlayingArtworkKey = station.id
                }
            }
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
            #endif
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
    #if os(iOS)
    // MediaPlayer invokes this handler on its own queue. Construct it outside
    // MainActor isolation so Swift does not insert a main-queue assertion.
    nonisolated private static func makeNowPlayingArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func clearLegacyActivities() {
        // iOS Now Playing owns the playback island. Remove activities from older builds,
        // including those left alive across app termination or a channel change.
        let activities = Activity<RadioActivityAttributes>.activities
        Task {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    #endif
}
