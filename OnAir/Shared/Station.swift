import Foundation
import SwiftUI

struct Station: Codable, Identifiable, Hashable, Sendable {
    let stationuuid: String
    let name: String
    let url_resolved: String
    let homepage: String
    let tags: String
    let bitrate: Int
    var id: String { stationuuid }
    var streamURL: URL? {
        guard let url = URL(string: url_resolved), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
    static let unavailableDirectoryIDs: Set<String> = [
        "8f6a0b47-7be2-11e9-aa30-52543be04c81",
        "fc4c247a-7f66-11e9-aa30-52543be04c81",
        "1cc29b79-7be3-11e9-aa30-52543be04c81",
        "730d9f95-57a3-4eec-94a2-ed270baa64c8",
        "e6bc48f7-7be2-11e9-aa30-52543be04c81",
        "8dc941a6-c866-4552-9fea-541c137cfb5d",
        "16c1e8aa-1e9e-422b-9611-842b61a70983",
        "01335461-d022-4ad8-9fbc-1bd3ef534def",
        "cb45bd69-ec15-4fe2-8a6f-0af262fb2aad",
        "8e068903-fbf8-4fac-aa9d-08b2b8d5eb47",
        "b2b7599e-16b9-4225-9ffa-263b0cb541a6",
        "44dc6d1c-abe5-402a-be20-3545a0a13101",
        "f9f853c9-51d7-4127-9796-5c838a786107",
    ]
    var isEligible: Bool {
        guard !Self.unavailableDirectoryIDs.contains(id) else { return false }
        let lower = name.lowercased()
        guard streamURL != nil else { return false }
        // User-reported unavailable station and directory entries with unsupported media.
        if ["평양", "pyongyang", "pyong yang", " tv", "vorbis"].contains(where: lower.contains) { return false }
        if streamURL?.host == "listen.moe", streamURL?.path == "/kpop/stream" { return false }
        return true
    }
    var homepageURL: URL? {
        guard let url = URL(string: homepage), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
    var subtitle: String {
        if catalogKey == "cbsstandard" { return "뉴스·시사와 다양한 이야기 · 표준FM 98.1" }
        if catalogKey == "cbsmusic" { return "음악으로 채우는 하루 · 음악FM 93.9" }
        if category == "뉴스·시사" { return "세상의 이야기 · 뉴스·시사" }
        if category == "클래식" { return "마음에 여백을 · 클래식" }
        if name.localizedCaseInsensitiveContains("kpop") || tags.lowercased().contains("k-pop") { return "오늘의 리듬 · K-POP" }
        return "함께 듣는 지금 · 한국 라디오"
    }
    var catalogKey: String {
        let compact = name.lowercased().filter { $0.isLetter || $0.isNumber }
        if ["cbs표준fm", "cbsstandardfm", "cbs표준", "cbs981"].contains(compact) { return "cbsstandard" }
        if ["cbs음악fm", "cbsmusicfm", "cbs939"].contains(compact) { return "cbsmusic" }
        if ["kbs1r", "kbs1radio", "kbs1라디오"].contains(compact) { return "kbs1radio" }
        if ["mbcfm", "mbc표준fm", "mbcstandardfm"].contains(compact) { return "mbcstandard" }
        if ["mbcfm4u", "mbcfmforyou"].contains(compact) { return "mbcfm4u" }
        if compact == "mbc올댓뮤직" { return "mbcallthat" }
        if ["sbspowerfm", "sbs파워fm"].contains(compact) { return "sbspower" }
        if ["sbslovefm", "sbs러브fm"].contains(compact) { return "sbslove" }
        if compact.hasPrefix("ytn") { return "ytnradio" }
        return compact
    }
    var logoAsset: String? {
        let key = catalogKey
        if key.hasPrefix("mbc") { return "StationLogoMBC" }
        if key.hasPrefix("sbs") { return "StationLogoSBS" }
        if key.hasPrefix("cbs") { return "StationLogoCBS" }
        if key.hasPrefix("kbs") { return "StationLogoKBS" }
        if key == "ytnradio" { return "StationLogoYTN" }
        return nil
    }
    var category: String {
        let lower = name.lowercased()
        let genre = tags.lowercased()
        if catalogKey == "cbsmusic" || lower.contains("fm4u") || lower.contains("fm for you") { return "음악" }
        if genre.contains("classic") || lower.contains("classic") { return "클래식" }
        if catalogKey == "mbcstandard" || catalogKey == "sbslove" || catalogKey == "cbsstandard" || catalogKey == "kbs1radio" || catalogKey == "ytnradio" || lower == "mbc fm" || lower.contains("표준fm") || lower.contains("sbs love") || genre.split(separator: ",").contains("news") {
            return "뉴스·시사"
        }
        return "음악"
    }
    var newsRegion: String? {
        guard category == "뉴스·시사" else { return nil }
        return ["부산", "대구", "대전", "광주", "울산", "제주", "경남", "경북", "전북", "전남", "충북", "충남", "강원", "춘천", "청주", "전주", "포항", "목포", "원주"].first { name.contains($0) }
    }
    static let categories = ["전체", "뉴스·시사", "음악", "클래식"]
    static let curated: [Station] = [
        Station(stationuuid: "mbc-standard-live", name: "MBC 표준FM", url_resolved: "https://minisw.imbc.com/dsfm/_definst_/sfm.stream/playlist.m3u8", homepage: "https://mini.imbc.com", tags: "news,talk", bitrate: 0),
        Station(stationuuid: "mbc-fm4u-live", name: "MBC FM4U", url_resolved: "https://minimw.imbc.com/dmfm/_definst_/mfm.stream/playlist.m3u8", homepage: "https://mini.imbc.com", tags: "music", bitrate: 0),
        Station(stationuuid: "mbc-allthat-live", name: "MBC 올댓뮤직", url_resolved: "https://minicw.imbc.com/dchm/_definst_/chm.stream/playlist.m3u8", homepage: "https://mini.imbc.com", tags: "music", bitrate: 0),
        Station(stationuuid: "sbs-power-live", name: "SBS 파워FM", url_resolved: "https://radiolive.sbs.co.kr/powerpc/powerfm.stream/playlist.m3u8", homepage: "https://www.sbs.co.kr/radio", tags: "music", bitrate: 0),
        Station(stationuuid: "sbs-love-live", name: "SBS 러브FM", url_resolved: "https://radiolive.sbs.co.kr/lovepc/lovefm.stream/playlist.m3u8", homepage: "https://www.sbs.co.kr/radio", tags: "news,talk", bitrate: 0),
        Station(stationuuid: "cbs-standard-fm", name: "CBS 표준FM", url_resolved: "https://m-aac.cbs.co.kr/mweb_cbs981/_definst_/cbs981.stream/playlist.m3u8", homepage: "https://www.cbs.co.kr/radio", tags: "news,talk", bitrate: 0),
        Station(stationuuid: "3043d560-4358-4583-9e29-9fce6777a09c", name: "CBS 음악FM", url_resolved: "https://m-aac.cbs.co.kr/mweb_cbs939/_definst_/cbs939.stream/playlist.m3u8", homepage: "https://www.cbs.co.kr/radio", tags: "music", bitrate: 0),
        Station(stationuuid: "10fbdfdd-2a6f-49fb-a035-8963c57f52e8", name: "YTN 라디오", url_resolved: "https://radiolive.ytn.co.kr/radio/_definst_/20211118_fmlive/playlist.m3u8", homepage: "https://radio.ytn.co.kr/", tags: "news,talk", bitrate: 0)
    ]
    var palette: Int { Int(name.utf8.reduce(0) { ($0 + Int($1)) % 4 }) }
    static let preview = Station(stationuuid: "preview", name: "온에어", url_resolved: "", homepage: "", tags: "", bitrate: 0)
}

struct RadioAudioOutput: Codable, Equatable, Sendable {
    var name: String
    var symbol: String
}

struct ListeningSnapshot: Codable {
    var station: Station?
    var favorites: [Station]
    var isPlaying: Bool
    var updatedAt: Date
    var sleepEnd: Date? = nil
    var buffering: Bool? = nil
    var audioOutput: RadioAudioOutput? = nil
}

enum SharedStore {
    static let group = "group.kr.davidkang.onair"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
    static func read() -> ListeningSnapshot {
        guard let data = defaults.data(forKey: "snapshot"), let value = try? JSONDecoder().decode(ListeningSnapshot.self, from: data) else {
            return .init(station: nil, favorites: [], isPlaying: false, updatedAt: .now)
        }
        var filtered = value
        filtered.favorites = value.favorites.filter(\.isEligible)
        if value.station?.isEligible == false { filtered.station = nil; filtered.isPlaying = false; filtered.buffering = false }
        return filtered
    }
    static func save(_ snapshot: ListeningSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: "snapshot")
    }
    static func link(_ station: Station?) -> URL {
        var parts = URLComponents(); parts.scheme = "onair"; parts.host = "play"
        if let station { parts.queryItems = [.init(name: "id", value: station.id)] }
        return parts.url!
    }
}

@MainActor @Observable final class StationLibrary {
    var stations: [Station] = Station.curated
    var loading = false
    var message: String?
    var favorites: [Station] = FavoriteOrder.sorted(SharedStore.read().favorites.filter(\.isEligible))
    init() {
        if let data = UserDefaults.standard.data(forKey: "verified-station-cache-v2") ?? Bundle.main.url(forResource: "stations", withExtension: "json").flatMap({ try? Data(contentsOf: $0) }) {
            stations = Self.clean((try? JSONDecoder().decode([Station].self, from: data)) ?? [])
        }
    }
    nonisolated static func clean(_ source: [Station]) -> [Station] {
        var names = Set<String>()
        return (Station.curated + source).filter { station in
            let name = station.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return station.isEligible && !name.contains(" tv") && names.insert(station.catalogKey).inserted
        }
    }
    var newsStations: [Station] {
        let priority = ["cbsstandard", "kbs1radio", "ytnradio"]
        return stations.filter { $0.category == "뉴스·시사" }.sorted {
            let left = priority.firstIndex(of: $0.catalogKey) ?? priority.count
            let right = priority.firstIndex(of: $1.catalogKey) ?? priority.count
            return left == right ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : left < right
        }
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        for host in ["de1.api.radio-browser.info", "nl1.api.radio-browser.info"] {
            do {
                let url = URL(string: "https://\(host)/json/stations/search?countrycode=KR&hidebroken=true&order=votes&reverse=true&limit=100")!
                var request = URLRequest(url: url); request.timeoutInterval = 12
                request.setValue("OnAir/1.0", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let result = Self.clean(try JSONDecoder().decode([Station].self, from: data))
                guard !result.isEmpty else { throw URLError(.zeroByteResource) }
                // Four checks at a time. Failed entries never enter the refreshed catalog.
                var verified: [Station] = []
                for start in stride(from: 0, to: result.count, by: 4) {
                    let batch = Array(result[start..<min(start + 4, result.count)])
                    await withTaskGroup(of: Void.self) { group in
                        for station in batch { group.addTask { await ConnectionHealth.shared.check(station, force: true) } }
                    }
                    guard !Task.isCancelled else { return }
                    verified += batch.filter { ConnectionHealth.shared.results[$0.id]?.state == .reachable }
                }
                guard !verified.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
                stations = verified; message = nil
                if let encoded = try? JSONEncoder().encode(verified) { UserDefaults.standard.set(encoded, forKey: "verified-station-cache-v2") }
                favorites = favorites.map { saved in verified.first(where: { $0.id == saved.id || $0.catalogKey == saved.catalogKey }) ?? saved }
                persist(); return
            } catch { if Task.isCancelled { return } }
        }
        message = "목록을 새로 불러오지 못했어요. 저장된 방송국을 표시합니다."
    }
    func toggle(_ station: Station) {
        #if !WIDGET_EXTENSION
        DeviceSync.shared.change(station, selected: !favorites.contains { $0.catalogKey == station.catalogKey })
        favorites = FavoriteOrder.sorted(SharedStore.read().favorites.filter(\.isEligible))
        persist()
        #else
        if favorites.contains(where: { $0.id == station.id }) { favorites.removeAll { $0.id == station.id } }
        else { favorites.append(station) }
        persist()
        #endif
    }
    func reorderFavorite(_ key: String, before target: String) {
        guard key != target, let from = favorites.firstIndex(where: { $0.catalogKey == key }), let to = favorites.firstIndex(where: { $0.catalogKey == target }) else { return }
        let station = favorites.remove(at: from); favorites.insert(station, at: to); FavoriteOrder.save(favorites); persist()
    }
    func shiftFavorite(_ key: String, offset: Int) {
        guard let index = favorites.firstIndex(where: { $0.catalogKey == key }), favorites.indices.contains(index + offset) else { return }
        favorites.swapAt(index, index + offset); FavoriteOrder.save(favorites); persist()
    }
    func moveFavorites(ids: [String], before targetID: String?) {
        favorites = FavoriteOrder.moving(favorites, ids: ids, before: targetID)
        FavoriteOrder.save(favorites)
        persist()
    }
    func reloadFavorites() { favorites = FavoriteOrder.sorted(SharedStore.read().favorites.filter(\.isEligible)) }
    func persist() {
        var snapshot = SharedStore.read(); snapshot.favorites = favorites; SharedStore.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
#if canImport(WidgetKit)
import WidgetKit
#endif

enum FavoriteOrder {
    static func moving(_ stations: [Station], ids: [String], before targetID: String?) -> [Station] {
        let selected = Set(ids)
        guard !selected.isEmpty, selected.isSubset(of: Set(stations.map(\.id))),
              targetID.map({ !selected.contains($0) }) != false else { return stations }
        let moving = stations.filter { selected.contains($0.id) }
        var remaining = stations.filter { !selected.contains($0.id) }
        let index: Int
        if let targetID {
            guard let destination = remaining.firstIndex(where: { $0.id == targetID }) else { return stations }
            index = destination
        } else { index = remaining.endIndex }
        remaining.insert(contentsOf: moving, at: index)
        return remaining
    }
    static func save(_ stations: [Station]) { SharedStore.defaults.set(stations.map(\.catalogKey), forKey: "favorite-order") }
    static func sorted(_ stations: [Station]) -> [Station] {
        let order = SharedStore.defaults.stringArray(forKey: "favorite-order") ?? []
        let rank = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        return stations.enumerated().sorted { (rank[$0.element.catalogKey] ?? (order.count + $0.offset)) < (rank[$1.element.catalogKey] ?? (order.count + $1.offset)) }.map(\.element)
    }
}
