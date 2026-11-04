import Foundation
import AppIntents
import Observation

enum RadioPresetKind: String, AppEnum, Codable, CaseIterable, Identifiable {
    case morning, commute, bedtime
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "하루의 라디오")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.morning: "출근", .commute: "퇴근", .bedtime: "취침"]
    var id: String { rawValue }
    var title: String { switch self { case .morning: "출근"; case .commute: "퇴근"; case .bedtime: "취침" } }
    var icon: String { switch self { case .morning: "sunrise"; case .commute: "tram"; case .bedtime: "moon.stars" } }
}
struct RadioPreset: Codable, Identifiable, Sendable {
    var kind: RadioPresetKind
    var station: Station
    var sleepMinutes: Int?
    var id: String { kind.rawValue }
}
@MainActor @Observable final class RadioPresets {
    static let shared = RadioPresets()
    var values: [RadioPreset] = []
    private init() { reload() }
    func reload() { values = Self.read() }
    nonisolated static func read() -> [RadioPreset] {
        ((SharedStore.defaults.data(forKey: "radio-presets").flatMap { try? JSONDecoder().decode([RadioPreset].self, from: $0) }) ?? []).filter { $0.station.isEligible }
    }
    func populate(from stations: [Station]) {
        guard !stations.isEmpty else { return }
        for kind in RadioPresetKind.allCases where !values.contains(where: { $0.kind == kind }) {
            let key = kind == .morning ? "cbsstandard" : kind == .commute ? "cbsmusic" : "kbsclassicfm"
            let station = stations.first { $0.catalogKey == key } ?? stations.first { $0.category == (kind == .morning ? "뉴스·시사" : kind == .bedtime ? "클래식" : "음악") } ?? stations[0]
            values.append(.init(kind: kind, station: station, sleepMinutes: kind == .bedtime ? 30 : nil))
        }
        save()
    }
    func update(_ preset: RadioPreset) {
        values.removeAll { $0.kind == preset.kind }; values.append(preset); values.sort { $0.kind.rawValue < $1.kind.rawValue }; save()
    }
    private func save() {
        SharedStore.defaults.set(try? JSONEncoder().encode(values), forKey: "radio-presets")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    func play(_ preset: RadioPreset) { RadioPlayer.shared.play(preset.station); RadioPlayer.shared.setSleep(minutes: preset.sleepMinutes) }
}
#if canImport(WidgetKit)
import WidgetKit
#endif
