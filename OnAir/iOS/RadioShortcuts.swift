import AppIntents

struct ListenToRadioIntent: AppIntent {
    static let title: LocalizedStringResource = "온에어 라디오 듣기"
    static let description = IntentDescription("최근 듣던 방송이나 즐겨찾기 방송을 온에어에서 재생합니다.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        let library = StationLibrary()
        await library.refresh()
        let saved = SharedStore.read().station
        if let station = library.stations.first(where: { $0.id == saved?.id }) ?? library.favorites.first ?? library.stations.first {
            RadioPlayer.shared.play(station)
        } else { throw RadioIntentError.noStations }
        return .result()
    }
}
enum RadioIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noStations
    var localizedStringResource: LocalizedStringResource { "방송국을 불러오지 못했어요. 앱에서 다시 시도해 주세요." }
}
#if os(iOS) && !WIDGET_EXTENSION
struct RadioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ListenToRadioIntent(), phrases: ["\(.applicationName) 라디오 틀어 줘", "\(.applicationName) 듣기"], shortTitle: "라디오 듣기", systemImageName: "dot.radiowaves.left.and.right")

        AppShortcut(intent: PlayCBSRadioIntent(channel: .standard), phrases: [
            "\(.applicationName)에서 CBS 라디오 틀어줘",
            "\(.applicationName)에서 씨비에스 라디오 틀어줘",
            "\(.applicationName)에서 CBS 뉴스 틀어줘"
        ], shortTitle: "CBS 라디오 듣기", systemImageName: "dot.radiowaves.left.and.right")
        AppShortcut(intent: PlayCBSRadioIntent(channel: .music), phrases: [
            "\(.applicationName)에서 CBS 음악FM 틀어줘",
            "\(.applicationName)에서 씨비에스 음악 틀어줘"
        ], shortTitle: "CBS 음악 듣기", systemImageName: "music.note")
    }
}
#endif
