import XCTest
@testable import OnAir

final class CatalogTests: XCTestCase {
    func testFavoriteDragReorderPreservesChannelsAndOrder() {
        let stations = Array(Station.curated.prefix(4))
        XCTAssertEqual(FavoriteOrder.moving(stations, ids: [stations[0].id], before: stations[2].id).map(\.id), [stations[1].id, stations[0].id, stations[2].id, stations[3].id])
        XCTAssertEqual(FavoriteOrder.moving(stations, ids: [stations[0].id, stations[2].id], before: nil).map(\.id), [stations[1].id, stations[3].id, stations[0].id, stations[2].id])
        XCTAssertEqual(FavoriteOrder.moving(stations, ids: ["missing"], before: nil), stations)
        XCTAssertEqual(FavoriteOrder.moving(stations, ids: [stations[0].id], before: stations[0].id), stations)
        XCTAssertEqual(FavoriteOrder.moving(stations, ids: [stations[0].id], before: "missing"), stations)
    }
    @MainActor func testRemoteVolumeClampsAndRejectsNonFiniteValues() {
        let saved = RadioPlayer.shared.volume
        defer { RadioPlayer.shared.volume = saved }
        DeviceSync.shared.performCommand("volume", station: nil, minutes: nil, volume: 0.35)
        XCTAssertEqual(RadioPlayer.shared.volume, 0.35)
        DeviceSync.shared.performCommand("volume", station: nil, minutes: nil, volume: 2)
        XCTAssertEqual(RadioPlayer.shared.volume, 1)
        DeviceSync.shared.performCommand("volume", station: nil, minutes: nil, volume: -1)
        XCTAssertEqual(RadioPlayer.shared.volume, 0)
        DeviceSync.shared.performCommand("volume", station: nil, minutes: nil, volume: .nan)
        XCTAssertEqual(RadioPlayer.shared.volume, 0)
    }
    @MainActor func testAirPlayCommandRequestsSystemPickerWithoutStartingAnUnselectedStation() {
        let request = expectation(forNotification: Notification.Name("onAirShowAirPlay"), object: nil)
        DeviceSync.shared.performCommand("airplay", station: nil, minutes: nil)
        wait(for: [request], timeout: 1)
    }
    func testOutputSnapshotRoundTripsAndAcceptsOldPayloads() throws {
        var snapshot = ListeningSnapshot(station: nil, favorites: [], isPlaying: false, updatedAt: .now)
        snapshot.audioOutput = .init(name: "거실 HomePod", symbol: "airplay.audio")
        let encoded = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(ListeningSnapshot.self, from: encoded).audioOutput, snapshot.audioOutput)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "audioOutput")
        XCTAssertNil(try JSONDecoder().decode(ListeningSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy)).audioOutput)
    }
    @MainActor func testBundledCatalogDecodesAndContainsKoreanBroadcasters() throws {
        let library = StationLibrary()
        XCTAssertGreaterThan(library.stations.count, 10)
        XCTAssertTrue(library.stations.contains { $0.name == "KBS Cool FM" })
        XCTAssertTrue(library.stations.allSatisfy { $0.streamURL != nil })
    }
    func testRejectsNonMediaURLSchemes() {
        let station = Station(stationuuid: "invalid", name: "Invalid", url_resolved: "file:///etc/passwd", homepage: "", tags: "", bitrate: 0)
        XCTAssertNil(station.streamURL)
    }
    func testWidgetLinkRoundTripsSpecialCharacters() throws {
        let station = Station(stationuuid: "한국 & jazz+1", name: "테스트", url_resolved: "https://example.com/live", homepage: "", tags: "", bitrate: 0)
        let components = try XCTUnwrap(URLComponents(url: SharedStore.link(station), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "onair")
        XCTAssertEqual(components.queryItems?.first?.value, station.id)
    }
    func testSnapshotPreservesSignedStreamQuery() throws {
        let station = Station(stationuuid: "signed", name: "테스트", url_resolved: "https://example.com/live?Policy=abc&Signature=a~b-c__", homepage: "", tags: "", bitrate: 128)
        let snapshot = ListeningSnapshot(station: station, favorites: [station], isPlaying: true, updatedAt: .now)
        let decoded = try JSONDecoder().decode(ListeningSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.station?.url_resolved, station.url_resolved)
        XCTAssertEqual(decoded.favorites, [station])
    }
    func testCBSStandardSurvivesEmptyDirectoryRefresh() {
        let stations = StationLibrary.clean([])
        XCTAssertTrue(stations.contains { $0.catalogKey == "cbsstandard" && $0.category == "뉴스·시사" })
        XCTAssertTrue(stations.contains { $0.catalogKey == "cbsmusic" && $0.category == "음악" })
    }
    func testCBSMusicAliasesDoNotCreateDuplicateChannels() {
        let alias = Station(stationuuid: "alias", name: "CBS 음악 FM", url_resolved: "https://example.com/music", homepage: "", tags: "news", bitrate: 0)
        let stations = StationLibrary.clean([alias])
        XCTAssertEqual(stations.filter { $0.catalogKey == "cbsmusic" }.count, 1)
        XCTAssertEqual(stations.first { $0.catalogKey == "cbsmusic" }?.category, "음악")
    }
    func testKBSNewsAliasDeduplication() {
        let first = Station(stationuuid: "one", name: "KBS 1R", url_resolved: "https://example.com/one", homepage: "", tags: "", bitrate: 0)
        let second = Station(stationuuid: "two", name: "KBS 1Radio", url_resolved: "https://example.com/two", homepage: "", tags: "", bitrate: 0)
        XCTAssertEqual(StationLibrary.clean([first, second]).filter { $0.catalogKey == "kbs1radio" }.count, 1)
        XCTAssertEqual(second.category, "뉴스·시사")
    }
    func testBackgroundAudioCapabilityIsInApplicationPlist() {
        XCTAssertTrue((Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []).contains("audio"))
    }
    func testRemovedAndUnsupportedStationsCannotReturnThroughDirectory() {
        let names = ["평양FM", "Pyongyang FM", "Listen.Moe KPop Vorbis", "Arirang TV"]
        let bad = names.enumerated().map { index, name in Station(stationuuid: "bad-\(index)", name: name, url_resolved: "https://example.com/live", homepage: "", tags: "", bitrate: 0) }
        XCTAssertTrue(StationLibrary.clean(bad).allSatisfy { !names.contains($0.name) })
        let stale = Station(stationuuid: Station.unavailableDirectoryIDs.sorted().first!, name: "오래된 주소", url_resolved: "https://example.com/live", homepage: "", tags: "", bitrate: 0)
        XCTAssertFalse(stale.isEligible)
    }

}
