import AppIntents
import Foundation

enum CBSChannel: String, AppEnum {
    case standard, music
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "CBS 방송")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .standard: "CBS 표준FM · 뉴스와 시사", .music: "CBS 음악FM"
    ]
    var catalogKey: String { self == .standard ? "cbsstandard" : "cbsmusic" }
}

struct PlayCBSRadioIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "CBS 라디오 듣기"
    static let description = IntentDescription("CBS 표준FM 또는 음악FM을 재생합니다. 알람 중단 자동화에도 사용할 수 있습니다.")
    static let openAppWhenRun = false
    @Parameter(title: "CBS 방송", default: .standard) var channel: CBSChannel
    static var parameterSummary: some ParameterSummary { Summary("\(\.$channel) 듣기") }
    init() {}
    init(channel: CBSChannel) { self.channel = channel }
    @MainActor func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let station = Station.curated.first(where: { $0.catalogKey == channel.catalogKey }) else { throw PlaybackIntentError.noStation }
        let player = RadioPlayer.shared
        player.play(station)
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(300))
            if player.isPlaying { return .result() }
            if player.error != nil || !player.buffering { throw PlaybackIntentError.connection }
        }
        throw PlaybackIntentError.connection
        #else
        return .result()
        #endif
    }
}

