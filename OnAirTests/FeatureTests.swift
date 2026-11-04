import XCTest
@testable import OnAir

final class FeatureTests: XCTestCase {
    @MainActor func testSleepFadeBoundsAndCancellation() {
        XCTAssertEqual(RadioPlayer.sleepFadeFactor(remaining: 60), 1)
        XCTAssertEqual(RadioPlayer.sleepFadeFactor(remaining: 15), 0.5)
        XCTAssertEqual(RadioPlayer.sleepFadeFactor(remaining: -1), 0)
        let player = RadioPlayer.shared
        player.setSleep(minutes: 1); XCTAssertNotNil(player.sleepEnd)
        player.setSleep(minutes: nil); XCTAssertNil(player.sleepEnd)
    }
    func testFavoriteOrderSurvivesMergedSnapshotWithNewStation() {
        let original = SharedStore.defaults.object(forKey: "favorite-order")
        defer { SharedStore.defaults.set(original, forKey: "favorite-order") }
        let stations = Array(Station.curated.prefix(3))
        FavoriteOrder.save([stations[1], stations[0]])
        XCTAssertEqual(FavoriteOrder.sorted(stations).map(\.catalogKey), [stations[1], stations[0], stations[2]].map(\.catalogKey))
    }
    let station = Station.curated[0]
    func testFreshAddressMappingAndSignedQuery() throws {
        for station in Station.curated.filter({ $0.catalogKey.hasPrefix("mbc") || $0.catalogKey.hasPrefix("sbs") }) {
            XCTAssertNotNil(StreamResolver.freshAddressAPI(for: station))
        }
        let address = "https://radiolive.sbs.co.kr/powerpc/powerfm.stream/playlist.m3u8?token=abc%2B123"
        XCTAssertEqual(try StreamResolver.parseAddress(Data(address.utf8)).absoluteString, address)
        XCTAssertThrowsError(try StreamResolver.parseAddress(Data("https://evil.example/stream".utf8)))
        XCTAssertThrowsError(try StreamResolver.parseAddress(Data("http://minimw.imbc.com/stream".utf8)))
    }
    @MainActor func testRecentPlaybackDeduplicatesAndCapsHistory() {
        let first = Station.curated[0], second = Station.curated[1]
        let entries = RecentListening.adding(first, at: Date(timeIntervalSince1970: 1), to: [])
        let updated = RecentListening.adding(first, at: Date(timeIntervalSince1970: 2), to: RecentListening.adding(second, at: .now, to: entries))
        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.first?.station.catalogKey, first.catalogKey)
        XCTAssertEqual(updated.first?.playedAt, Date(timeIntervalSince1970: 2))
        let many = Array(Station.curated + Station.curated).reduce([RecentStation]()) { RecentListening.adding($1, at: .now, to: $0) }
        XCTAssertLessThanOrEqual(many.count, 12)
        XCTAssertEqual(Set(many.map { $0.station.catalogKey }).count, many.count)
    }
    func testFavoriteDeletionWinsOverOlderSave() {
        let old = FavoriteChange(station: station, selected: true, changedAt: Date(timeIntervalSince1970: 10), revision: "a")
        let deleted = FavoriteChange(station: station, selected: false, changedAt: Date(timeIntervalSince1970: 20), revision: "b")
        let merged = FavoriteMerge.merge([station.catalogKey: deleted], [station.catalogKey: old])
        XCTAssertTrue(FavoriteMerge.stations(merged).isEmpty)
        XCTAssertEqual(merged[station.catalogKey], deleted)
    }
    func testConcurrentFavoritesMergeWithoutDroppingOtherDeviceChanges() {
        let other = Station.curated[1]
        let a = FavoriteChange(station: station, selected: true, changedAt: .now, revision: "a")
        let b = FavoriteChange(station: other, selected: true, changedAt: .now, revision: "b")
        let merged = FavoriteMerge.merge([station.catalogKey: a], [other.catalogKey: b])
        XCTAssertEqual(Set(FavoriteMerge.stations(merged).map(\.catalogKey)), Set([station.catalogKey, other.catalogKey]))
        XCTAssertEqual(FavoriteMerge.merge(merged, merged), merged)
    }
    func testFavoriteTieMergeConvergesInBothDirections() {
        let date = Date(timeIntervalSince1970: 12)
        let a = FavoriteChange(station: station, selected: true, changedAt: date, revision: "a")
        let b = FavoriteChange(station: station, selected: false, changedAt: date, revision: "b")
        XCTAssertEqual(FavoriteMerge.merge([station.catalogKey: a], [station.catalogKey: b]), FavoriteMerge.merge([station.catalogKey: b], [station.catalogKey: a]))
    }
    func testScheduleRejectsYesterdayAndUsesKoreanTimezone() throws {
        let data = Data(#"{"fm":[{"date":"2026-10-06","startTime":"17:00","endTime":"17:30","name":"CBS 경제연구실"},{"date":"2026-10-05","startTime":"17:00","endTime":"17:30","name":"어제 방송"}]}"#.utf8)
        let day = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-06T01:00:00Z"))
        let programs = try CBSProgramParser.parse(data, for: day)
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs[0].startsAt, ISO8601DateFormatter().date(from: "2026-10-06T08:00:00Z"))
        XCTAssertEqual(programs[0].topic, .economy)
        XCTAssertFalse(programs[0].isLive(at: programs[0].endsAt))
        XCTAssertTrue(try CBSProgramParser.parse(data, for: day.addingTimeInterval(86400)).isEmpty)
    }
    func testScheduleMidnightAndMalformedTimes() throws {
        let data = Data(#"{"musicfm":[{"date":"2026-10-06","startTime":"23:00","endTime":"00:00","name":"밤의 음악"},{"date":"2026-10-06","startTime":"99:00","endTime":"00:00","name":"잘못된 시간"}]}"#.utf8)
        let date = try XCTUnwrap(CBSProgramParser.time("12:00", day: "2026-10-06"))
        let programs = try CBSProgramParser.parse(data, for: date)
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs[0].endsAt.timeIntervalSince(programs[0].startsAt), 3600)
        XCTAssertEqual(CBSProgramParser.time("24:00", day: "2026-10-06"), programs[0].endsAt)
    }
    func testNewsTopicsDoNotClassifyMusicAsNews() {
        XCTAssertEqual(NewsTopic.classify("김현정의 뉴스쇼"), .discussion)
        XCTAssertEqual(NewsTopic.classify("CBS news"), .headlines)
        XCTAssertEqual(NewsTopic.classify("지역 뉴스"), .local)
        XCTAssertNil(NewsTopic.classify("그대 창가에 알렉스입니다"))
    }
    func testLegacySnapshotRemainsReadable() throws {
        let data = Data(#"{"favorites":[],"isPlaying":false,"updatedAt":0}"#.utf8)
        let snapshot = try JSONDecoder().decode(ListeningSnapshot.self, from: data)
        XCTAssertNil(snapshot.buffering); XCTAssertNil(snapshot.sleepEnd)
    }
    func testPresetPreservesStationAndSleepTimer() throws {
        let value = RadioPreset(kind: .bedtime, station: station, sleepMinutes: 30)
        let decoded = try JSONDecoder().decode(RadioPreset.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded.station, station); XCTAssertEqual(decoded.sleepMinutes, 30); XCTAssertEqual(decoded.kind, .bedtime)
    }
    @MainActor func testStaleWidgetPauseDoesNotStopDifferentChannel() async throws {
        let value = Station(stationuuid: "new-channel", name: "새 방송", url_resolved: "http://127.0.0.1:9/live.m3u8", homepage: "", tags: "", bitrate: 0)
        let player = RadioPlayer.shared; player.play(value)
        _ = try await RadioPlaybackIntent(stationID: "old-channel", shouldPause: true).perform()
        XCTAssertTrue(player.buffering)
        XCTAssertEqual(player.station?.id, "new-channel")
        player.pause(); player.error = nil
    }
    @MainActor func testAutomaticReconnectStopsAfterThreeAttempts() async throws {
        let bad = Station(stationuuid: "retry-limit-test", name: "연결 한도 테스트", url_resolved: "http://127.0.0.1:9/live.m3u8", homepage: "", tags: "", bitrate: 0)
        let player = RadioPlayer.shared
        player.play(bad)
        for _ in 0..<120 {
            if player.error != nil { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertNotNil(player.error)
        XCTAssertEqual(player.reconnectAttempt, 3)
        XCTAssertFalse(player.buffering); XCTAssertFalse(player.isPlaying)
        player.pause(); player.error = nil
    }
    @MainActor func testUserPauseCancelsPendingReconnect() async throws {
        let bad = Station(stationuuid: "unreachable-test", name: "연결 실패 테스트", url_resolved: "http://127.0.0.1:9/live.m3u8", homepage: "", tags: "", bitrate: 0)
        let player = RadioPlayer.shared
        player.play(bad)
        for _ in 0..<120 {
            if player.reconnectAttempt > 0 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThan(player.reconnectAttempt, 0, "실패한 스트림에서 재연결을 시작해야 합니다")
        player.pause()
        try await Task.sleep(for: .seconds(3))
        XCTAssertFalse(player.buffering); XCTAssertFalse(player.isPlaying)
        player.error = nil
    }
}
