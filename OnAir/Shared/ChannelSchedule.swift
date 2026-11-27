import Foundation

enum ChannelSchedule {
    static let kbsChannels = ["21": "kbs1radio", "22": "kbs2r", "23": "kbs3r", "24": "kbsclassicfm", "25": "kbscoolfm", "26": "kbshanminjok"]
    static func officialURL(for station: Station) -> URL? {
        let key = station.catalogKey
        if key == "cbsstandard" || key == "cbsmusic" { return URL(string: "https://www.cbs.co.kr/schedule?type=\(key == "cbsstandard" ? "fm" : "musicFm")") }
        if key.hasPrefix("kbs") { return URL(string: "https://schedule.kbs.co.kr/index.html?sname=schedule&stype=table&type=radioList") }
        if key.hasPrefix("mbc") { return URL(string: "https://miniwebapp.imbc.com/index?channel=\(key == "mbcstandard" ? "sfm" : key == "mbcfm4u" ? "mfm" : "chm")") }
        if key.hasPrefix("sbs") { return URL(string: "https://www.sbs.co.kr/schedule") }
        return station.homepageURL
    }
    struct KBSChannel: Decodable {
        let channel_code: String
        let schedules: [KBSRow]
    }
    struct KBSRow: Decodable {
        let program_planned_date: String
        let program_planned_start_time: String
        let program_planned_end_time: String
        let program_title: String
        let programming_table_title: String?
    }
    static func parseKBS(_ data: Data, for date: Date) throws -> [RadioProgram] {
        let day = CBSProgramParser.dayKey(date)
        let channels = try JSONDecoder().decode([KBSChannel].self, from: data)
        return channels.flatMap { channel -> [RadioProgram] in
            guard let key = kbsChannels[channel.channel_code] else { return [] }
            return channel.schedules.compactMap { row in
                let rowDay = row.program_planned_date
                guard rowDay.count == 8 else { return nil }
                let calendarDay = String(rowDay.prefix(4)) + "-" + String(rowDay.dropFirst(4).prefix(2)) + "-" + String(rowDay.suffix(2))
                func time(_ value: String) -> Date? {
                    guard value.count >= 4, let hour = Int(value.prefix(2)), let minute = Int(value.dropFirst(2).prefix(2)), (0...47).contains(hour), (0...59).contains(minute), let midnight = CBSProgramParser.time("00:00", day: calendarDay) else { return nil }
                    return CBSProgramParser.calendar.date(byAdding: .minute, value: hour * 60 + minute, to: midnight)
                }
                guard let start = time(row.program_planned_start_time), var end = time(row.program_planned_end_time) else { return nil }
                if end <= start { end = end.addingTimeInterval(86400) }
                guard let midnight = CBSProgramParser.time("00:00", day: day), start < midnight.addingTimeInterval(86400), end > midnight else { return nil }
                let title = row.programming_table_title.flatMap { $0.isEmpty ? nil : $0 } ?? row.program_title
                guard !title.isEmpty else { return nil }
                return RadioProgram(stationKey: key, title: title, startsAt: start, endsAt: end, source: URL(string: "https://schedule.kbs.co.kr/index.html?sname=schedule&stype=table&type=radioList")!)
            }
        }.sorted { $0.startsAt < $1.startsAt }
    }
    struct MBCRow: Decodable {
        let Channel: String
        let StartTime: String
        let EndTime: String
        let ProgramTitle: String
        let LiveDays: String
    }
    static func parseMBC(_ data: Data, for date: Date) throws -> [RadioProgram] {
        let day = CBSProgramParser.dayKey(date)
        let weekday = ["일", "월", "화", "수", "목", "금", "토"][CBSProgramParser.calendar.component(.weekday, from: date) - 1]
        let rows = try JSONDecoder().decode([MBCRow].self, from: data)
        let keys = ["STFM": "mbcstandard", "FM4U": "mbcfm4u", "CHAM": "mbcallthat"]
        var seen = Set<String>()
        return rows.compactMap { row in
            guard row.LiveDays.contains(weekday), let key = keys[row.Channel], !row.ProgramTitle.isEmpty else { return nil }
            func time(_ value: String) -> Date? {
                guard value.count == 4 else { return nil }
                return CBSProgramParser.time(String(value.prefix(2)) + ":" + String(value.suffix(2)), day: day)
            }
            guard let start = time(row.StartTime), var end = time(row.EndTime) else { return nil }
            if end <= start { end = end.addingTimeInterval(86400) }
            let program = RadioProgram(stationKey: key, title: row.ProgramTitle, startsAt: start, endsAt: end, source: URL(string: "https://miniwebapp.imbc.com/index?channel=\(key == "mbcstandard" ? "sfm" : key == "mbcfm4u" ? "mfm" : "chm")")!)
            guard seen.insert(program.id).inserted else { return nil }
            return program
        }.sorted { $0.startsAt < $1.startsAt }
    }
    static func fetchMBC(for date: Date) async throws -> [RadioProgram] {
        var request = URLRequest(url: URL(string: "https://miniapi.imbc.com/Schedule/schedulelist")!); request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 3_000_000 else { throw URLError(.badServerResponse) }
        return try parseMBC(data, for: date)
    }
    static func fetchKBS(for date: Date) async throws -> [RadioProgram] {
        let day = CBSProgramParser.dayKey(date).replacingOccurrences(of: "-", with: "")
        let previous = CBSProgramParser.dayKey(date.addingTimeInterval(-86400)).replacingOccurrences(of: "-", with: "")
        let url = URL(string: "https://static.api.kbs.co.kr/mediafactory/v1/schedule/weekly?local_station_code=00&channel_code=21,22,23,24,25,26&program_planned_date_from=\(previous)&program_planned_date_to=\(day)")!
        var request = URLRequest(url: url); request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 3_000_000 else { throw URLError(.badServerResponse) }
        return try parseKBS(data, for: date)
    }
}

// MARK: - 지금 나오는 곡 · 선곡표
// 방송사 웹 플레이어가 쓰는 공개 엔드포인트입니다. 로그인·키가 필요 없지만 공식 API가 아니므로
// 응답이 바뀌면 조용히 빈 값으로 처리합니다. (확인: 2026-11-26)

struct RadioSong: Codable, Hashable, Identifiable, Sendable {
    var title: String
    var artist: String
    var playedAt: Date?
    var albumImage: URL?
    var id: String { "\(title)|\(artist)|\(playedAt?.timeIntervalSince1970 ?? 0)" }
}

struct SongBoard: Codable, Sendable, Equatable {
    var program: String?
    /// 최신 곡이 앞에 옵니다.
    var songs: [RadioSong]
    var fetchedAt: Date
    /// 최근 8분 안에 시작한 곡만 '지금 나오는 곡'으로 봅니다. 토크 중에는 비워 둡니다.
    func current(at date: Date = .now) -> RadioSong? {
        guard let first = songs.first else { return nil }
        guard let played = first.playedAt else { return date.timeIntervalSince(fetchedAt) < 120 ? first : nil }
        return date.timeIntervalSince(played) < 480 ? first : nil
    }
}

enum SongFeed {
    static let kbsCodes = ["kbs1radio": "21", "kbs2r": "22", "kbscoolfm": "25"]
    static let sbsCodes = ["sbspower": "S07", "sbslove": "S08"]
    static let mbcCodes = ["mbcstandard": "STFM", "mbcfm4u": "FM4U"]
    static func supports(_ station: Station) -> Bool {
        let key = station.catalogKey
        return kbsCodes[key] != nil || sbsCodes[key] != nil || mbcCodes[key] != nil
    }

    static func fetch(_ station: Station, now: Date = .now) async throws -> SongBoard {
        let key = station.catalogKey
        let day = CBSProgramParser.dayKey(now).replacingOccurrences(of: "-", with: "")
        if let code = mbcCodes[key] {
            let data = try await get("https://miniunit.imbc.com/list/somitem?rtype=json")
            guard let now = try parseMBCNow(data, channel: code) else { return SongBoard(program: nil, songs: [], fetchedAt: .now) }
            var songs = [now.song]
            if let listData = try? await get("https://miniunit.imbc.com/list/SomList?bid=\(now.bid)&gid=\(now.gid)&rtype=json") {
                let list = (try? parseMBCList(listData)) ?? []
                songs += list.filter { !($0.title == now.song.title && $0.artist == now.song.artist) }
            }
            return SongBoard(program: nil, songs: songs, fetchedAt: .now)
        }
        if let channel = sbsCodes[key] {
            let info = try parseSBSOnair(try await get("https://apis.sbs.co.kr/play-api/1.0/onair/channel/\(channel)?v_type=2&platform=pcweb&protocol=hls&ssl=Y&jwt-token="))
            let songs = (try? parseSBSPlaylist(try await get("https://apis.sbs.co.kr/radio-api/playlist/\(info.programID)/\(day)"))) ?? []
            return SongBoard(program: info.title, songs: songs, fetchedAt: .now)
        }
        if let code = kbsCodes[key] {
            let program = try parseKBSOnair(try await get("https://static.api.kbs.co.kr/mediafactory/v1/schedule/onair_now?rtype=json&local_station_code=00&channel_code=\(code)"))
            let songs = (try? parseKBSSongs(try await get("https://kong2017.kbs.co.kr/api/mobile/select_song_list?request_date=\(day)&program_code=\(program.code)"))) ?? []
            return SongBoard(program: program.title, songs: songs, fetchedAt: .now)
        }
        throw URLError(.unsupportedURL)
    }

    private static func get(_ text: String) async throws -> Data {
        guard let url = URL(string: text) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData); request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 2_000_000 else { throw URLError(.badServerResponse) }
        return data
    }
    static func stamp(_ text: String) -> Date? {
        let digits = text.filter(\.isNumber)
        guard digits.count >= 14 else { return nil }
        var parts = DateComponents()
        let n = Array(digits)
        func int(_ from: Int, _ length: Int) -> Int? { Int(String(n[from..<from + length])) }
        parts.year = int(0, 4); parts.month = int(4, 2); parts.day = int(6, 2); parts.hour = int(8, 2); parts.minute = int(10, 2); parts.second = int(12, 2)
        return CBSProgramParser.calendar.date(from: parts)
    }
    static func clean(_ text: String) -> String {
        var value = text
        for (entity, plain) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")] { value = value.replacingOccurrences(of: entity, with: plain) }
        value = value.replacingOccurrences(of: "Ψ", with: ", ") // KBS는 여러 가수를 Ψ로 이어 보냅니다
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MBC: "♬제목 - 가수"
    struct MBCNow { var song: RadioSong; var bid: String; var gid: String }
    static func parseMBCNow(_ data: Data, channel: String) throws -> MBCNow? {
        struct Item: Decodable { let Channel: String; let BroadcastID: String?; let GroupID: String?; let RegDate: String?; let SomItem: String? }
        struct Body: Decodable { let SomItemList: [Item]? }
        guard let item = try JSONDecoder().decode(Body.self, from: data).SomItemList?.first(where: { $0.Channel == channel }),
              let raw = item.SomItem, let bid = item.BroadcastID, let gid = item.GroupID else { return nil }
        let text = clean(raw.replacingOccurrences(of: "♬", with: ""))
        guard !text.isEmpty else { return nil }
        let parts = text.components(separatedBy: " - ")
        let title = parts.count > 1 ? parts.dropLast().joined(separator: " - ") : text
        let artist = parts.count > 1 ? parts.last! : ""
        return MBCNow(song: RadioSong(title: title, artist: artist, playedAt: item.RegDate.flatMap(stamp)), bid: bid, gid: gid)
    }
    static func parseMBCList(_ data: Data) throws -> [RadioSong] {
        struct Item: Decodable { let TrackTitle: String?; let ArtistName: String?; let AlbumImageUrl: String?; let Seq_no: String? }
        let items = try JSONDecoder().decode([Item].self, from: data)
        // 순번이 큰 곡이 나중에 나온 곡입니다.
        return items.sorted { (Int($0.Seq_no ?? "") ?? 0) > (Int($1.Seq_no ?? "") ?? 0) }.compactMap { item in
            guard let title = item.TrackTitle.map(clean), !title.isEmpty else { return nil }
            return RadioSong(title: title, artist: clean(item.ArtistName ?? ""), playedAt: nil, albumImage: item.AlbumImageUrl.flatMap { $0.isEmpty ? nil : URL(string: $0) })
        }
    }

    // SBS
    static func parseSBSOnair(_ data: Data) throws -> (programID: String, title: String?) {
        struct Info: Decodable { let programid: String?; let title: String? }
        struct Onair: Decodable { let info: Info }
        struct Body: Decodable { let onair: Onair }
        let info = try JSONDecoder().decode(Body.self, from: data).onair.info
        guard let id = info.programid, !id.isEmpty, id.allSatisfy(\.isNumber) else { throw URLError(.cannotParseResponse) }
        return (id, info.title)
    }
    static func parseSBSPlaylist(_ data: Data) throws -> [RadioSong] {
        struct Item: Decodable {
            let SONG_TITLE: String?; let ARTIST_NAME: String?; let ALBUM_IMG: String?; let START_TIME: Int64?
        }
        struct Inner: Decodable { let playlist: [Item]? }
        struct Body: Decodable { let data: Inner? }
        let items = try JSONDecoder().decode(Body.self, from: data).data?.playlist ?? []
        return items.compactMap { item in
            guard let title = item.SONG_TITLE.map(clean), !title.isEmpty else { return nil }
            return RadioSong(title: title, artist: clean(item.ARTIST_NAME ?? ""), playedAt: item.START_TIME.flatMap { stamp(String($0)) }, albumImage: item.ALBUM_IMG.flatMap(URL.init(string:)))
        }.sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
    }

    // KBS
    static func parseKBSOnair(_ data: Data) throws -> (code: String, title: String?) {
        struct Row: Decodable { let program_code: String?; let program_title: String? }
        struct Channel: Decodable { let schedules: [Row] }
        guard let row = try JSONDecoder().decode([Channel].self, from: data).first?.schedules.first,
              let code = row.program_code, !code.isEmpty, code.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { throw URLError(.cannotParseResponse) }
        return (code, row.program_title)
    }
    static func parseKBSSongs(_ data: Data) throws -> [RadioSong] {
        struct Item: Decodable { let song_title: String?; let artist: String?; let album_image: String?; let timestamp: String? }
        struct Body: Decodable { let items: [Item]? }
        return (try JSONDecoder().decode(Body.self, from: data).items ?? []).compactMap { item in
            guard let title = item.song_title.map(clean), !title.isEmpty else { return nil }
            return RadioSong(title: title, artist: clean(item.artist ?? ""), playedAt: item.timestamp.flatMap(stamp), albumImage: item.album_image.flatMap(URL.init(string:)))
        }.sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
    }
}

@MainActor @Observable final class NowPlayingSongs {
    static let shared = NowPlayingSongs()
    var boards: [String: SongBoard] = [:]
    var loading: Set<String> = []
    private init() {}
    func board(for station: Station) -> SongBoard? { boards[station.catalogKey] }
    func current(for station: Station, at date: Date = .now) -> RadioSong? { boards[station.catalogKey]?.current(at: date) }
    func refresh(_ station: Station, force: Bool = false) async {
        let key = station.catalogKey
        guard SongFeed.supports(station), !loading.contains(key) else { return }
        if !force, let board = boards[key], Date.now.timeIntervalSince(board.fetchedAt) < 30 { return }
        loading.insert(key); defer { loading.remove(key) }
        if let board = try? await SongFeed.fetch(station) { boards[key] = board }
    }
}
