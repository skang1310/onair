#if os(iOS)
import AlarmKit
import AppIntents
import SwiftUI

struct WakeRadioMetadata: AlarmMetadata { let stationID: String }
struct WakeRadioStopIntent: LiveActivityIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "기상 라디오 시작"
    static let openAppWhenRun = false
    @Parameter(title: "알람 ID") var alarmID: String
    @Parameter(title: "방송 ID") var stationID: String
    init() {}
    init(alarmID: UUID, stationID: String) { self.alarmID = alarmID.uuidString; self.stationID = stationID }
    @MainActor func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try? AlarmManager.shared.stop(id: id) }
        _ = try await RadioPlaybackIntent(stationID: stationID, shouldPause: false).perform()
        return .result()
    }
}
@MainActor enum WakeRadio {
    static func schedule(time: Date, station: Station, weekdays: Bool) async throws {
        guard try await AlarmManager.shared.requestAuthorization() == .authorized else { throw WakeError.denied }
        let id = UUID()
        let pieces = Calendar.current.dateComponents([.hour, .minute], from: time)
        let relative = Alarm.Schedule.Relative(time: .init(hour: pieces.hour ?? 7, minute: pieces.minute ?? 0), repeats: weekdays ? .weekly([.monday,.tuesday,.wednesday,.thursday,.friday]) : .never)
        let alert = AlarmPresentation.Alert(title: "라디오로 시작하는 아침", stopButton: .init(text: "끄고 라디오 듣기", textColor: .white, systemImageName: "radio"))
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: WakeRadioMetadata(stationID: station.id), tintColor: RadioDesign.coral)
        _ = try await AlarmManager.shared.schedule(id: id, configuration: .alarm(schedule: .relative(relative), attributes: attributes, stopIntent: WakeRadioStopIntent(alarmID: id, stationID: station.id)))
        let previous = SharedStore.defaults.string(forKey: "wake-radio-id").flatMap(UUID.init(uuidString:))
        SharedStore.defaults.set(id.uuidString, forKey: "wake-radio-id")
        SharedStore.defaults.set(station.name, forKey: "wake-radio-station")
        SharedStore.defaults.set(station.id, forKey: "wake-radio-station-id")
        SharedStore.defaults.set(time, forKey: "wake-radio-time")
        SharedStore.defaults.set(weekdays, forKey: "wake-radio-weekdays")
        if let previous { try? AlarmManager.shared.cancel(id: previous) }
    }
    static func cancel() throws {
        if let id = SharedStore.defaults.string(forKey: "wake-radio-id").flatMap(UUID.init(uuidString:)) { try AlarmManager.shared.cancel(id: id) }
        SharedStore.defaults.removeObject(forKey: "wake-radio-id"); SharedStore.defaults.removeObject(forKey: "wake-radio-station")
    }
    enum WakeError: Error { case denied }
}
#endif
