import Foundation
import Observation

struct RecentStation: Codable, Equatable {
    let station: Station
    let playedAt: Date
}

@MainActor @Observable final class RecentListening {
    static let shared = RecentListening()
    private(set) var entries: [RecentStation]
    private static let key = "recent-stations-v1"
    private init() {
        entries = (SharedStore.defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([RecentStation].self, from: $0) } ?? []).filter { $0.station.isEligible }
    }
    static func adding(_ station: Station, at date: Date, to entries: [RecentStation]) -> [RecentStation] {
        guard station.isEligible else { return entries }
        return Array(([RecentStation(station: station, playedAt: date)] + entries.filter { $0.station.isEligible && $0.station.catalogKey != station.catalogKey }).prefix(12))
    }
    func record(_ station: Station) {
        entries = Self.adding(station, at: .now, to: entries)
        SharedStore.defaults.set(try? JSONEncoder().encode(entries), forKey: Self.key)
    }
    func clear() { entries = []; SharedStore.defaults.removeObject(forKey: Self.key) }
}
