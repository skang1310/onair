import Foundation
import AppIntents

struct RadioPlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "라디오 재생 제어"
    static let openAppWhenRun = false
    @Parameter(title: "방송 ID") var stationID: String
    @Parameter(title: "일시정지") var shouldPause: Bool
    init() {}
    init(stationID: String, shouldPause: Bool) { self.stationID = stationID; self.shouldPause = shouldPause }
    @MainActor func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let player = RadioPlayer.shared
        if shouldPause { if player.station?.id == stationID { player.pause() }; return .result() }
        let library = StationLibrary()
        let saved = SharedStore.read()
        let choices = library.stations + saved.favorites + RadioPresets.read().map(\.station) + [saved.station].compactMap { $0 }
        guard let station = choices.first(where: { $0.id == stationID }) else { throw PlaybackIntentError.noStation }
        player.play(station)
        // AudioPlaybackIntent runs in the app process; wait for the initial audio connection.
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(300))
            if player.isPlaying || player.error != nil || !player.buffering { break }
        }
        if player.error != nil || !player.isPlaying { throw PlaybackIntentError.connection }
        #endif
        return .result()
    }
}
struct PlayRadioPresetIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "하루의 라디오 듣기"
    static let openAppWhenRun = false
    @Parameter(title: "프리셋") var kind: RadioPresetKind
    init() {}
    init(kind: RadioPresetKind) { self.kind = kind }
    @MainActor func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let presets = RadioPresets.shared; presets.populate(from: StationLibrary().stations)
        guard let preset = presets.values.first(where: { $0.kind == kind }) else { throw PlaybackIntentError.noStation }
        presets.play(preset)
        for _ in 0..<100 { try await Task.sleep(for: .milliseconds(300)); if !RadioPlayer.shared.buffering { break } }
        if RadioPlayer.shared.error != nil { throw PlaybackIntentError.connection }
        #endif
        return .result()
    }
}
enum PlaybackIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noStation, connection
    var localizedStringResource: LocalizedStringResource {
        switch self { case .noStation: "앱에서 방송을 먼저 선택해 주세요."; case .connection: "방송 연결을 확인해 주세요." }
    }
}
