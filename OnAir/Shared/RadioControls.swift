#if os(iOS)
import SwiftUI
import WidgetKit
import AppIntents
struct QuickRadioControlIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "내 라디오 재생·정지"
    static let openAppWhenRun = false
    @MainActor func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let player = RadioPlayer.shared
        if player.isPlaying || player.buffering { player.pause() }
        else {
            let station = SharedStore.read().station ?? Station.curated.first { $0.catalogKey == "cbsstandard" }
            guard let station else { throw PlaybackIntentError.noStation }
            _ = try await RadioPlaybackIntent(stationID: station.id, shouldPause: false).perform()
        }
        #endif
        return .result()
    }
}
struct OnAirRadioControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "OnAirQuickRadio") {
            ControlWidgetButton(action: QuickRadioControlIntent()) { Label("내 라디오", systemImage: "radio") }
        }.displayName("내 라디오").description("재생·정지. 최근 방송을 재생합니다.")
    }
}
#endif
