import SwiftUI
import WidgetKit
@preconcurrency import MediaPlayer

struct ConnectionBadge: View {
    let station: Station
    @State private var health = ConnectionHealth.shared
    var body: some View {
        if let status = health.results[station.id] {
            Label(status.label, systemImage: status.state == .reachable ? "checkmark.circle" : status.state == .checking ? "arrow.triangle.2.circlepath" : "exclamationmark.circle")
                .font(.caption2).foregroundStyle(status.state == .reachable ? Color.teal : Color.secondary)
                .accessibilityLabel(status.detail)
        } else {
            Text("연결 미확인").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
struct ProgramList: View {
    let programs: [RadioProgram]
    @Bindable var library: StationLibrary
    @State private var reminders = ProgramReminders.shared
    var body: some View {
        ForEach(programs) { program in
            HStack(alignment: .center, spacing: 12) {
                Button {
                    if let station = library.stations.first(where: { $0.catalogKey == program.stationKey }) { RadioPlayer.shared.play(station) }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(program.startsAt, style: .time).font(.caption.monospacedDigit())
                            if program.isLive(at: .now) { Text("방송 중").font(.caption2.bold()).foregroundStyle(RadioDesign.coral) }
                        }
                        Text(program.title).font(.subheadline.weight(.semibold))
                        Text(library.stations.first { $0.catalogKey == program.stationKey }?.name ?? program.stationKey).font(.caption).foregroundStyle(.secondary)
                        if reminders.scheduledIDs.contains("program." + program.id) { Text("시작 5분 전 알림 예약됨").font(.caption2).foregroundStyle(.teal) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { Task { await reminders.toggle(program) } } label: {
                    Image(systemName: reminders.followed.contains(program.followKey) ? "bell.badge.fill" : "bell")
                        .frame(width: 44, height: 44).foregroundStyle(RadioDesign.coral)
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(program.title) 시작 알림 \(reminders.followed.contains(program.followKey) ? "해제" : "설정")")
            }.listRowBackground(RadioDesign.surface.opacity(0.85))
        }
    }
}
struct ScheduleView: View {
    @Bindable var library: StationLibrary
    let stationKey: String?
    @State private var selectedKey = "cbsstandard"
    @State private var schedule = ProgramSchedule.shared
    @State private var reminders = ProgramReminders.shared
    var selectedStation: Station? { library.stations.first { $0.catalogKey == selectedKey } }
    var programs: [RadioProgram] { schedule.programs.filter { $0.stationKey == selectedKey } }
    var body: some View {
        List {
            Section {
                Picker("라디오 채널", selection: $selectedKey) {
                    ForEach(library.stations) { station in Text(station.name).tag(station.catalogKey) }
                }.accessibilityIdentifier("schedule-channel-picker")
                if let station = selectedStation {
                    HStack(spacing: 14) {
                        StationArtwork(station: station).frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(station.name).font(.headline).accessibilityIdentifier("schedule-station-name")
                            Text(Date.now, format: .dateTime.month().day().weekday()).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { RadioPlayer.shared.play(station) } label: { Image(systemName: "play.fill").frame(width: 44, height: 44) }.buttonStyle(.bordered).buttonBorderShape(.circle).accessibilityLabel("선택한 채널 듣기")
                    }.padding(.vertical, 8)
                }
            }
            Section {
                ProgramList(programs: programs, library: library)
                if schedule.loading { ProgressView("오늘 편성표를 불러옵니다") }
                if programs.isEmpty && !schedule.loading {
                    ContentUnavailableView("편성표는 공식 채널에서", systemImage: "calendar", description: Text("이 채널의 오늘 일정을 앱에서 확인하지 못했어요. 아래 공식 편성표를 열어 주세요."))
                }
            } header: { Text("오늘 · 한국 시간") } footer: {
                Text(selectedKey.hasPrefix("mbc") ? "MBC 공식 요일별 정규 편성 · 특별 편성은 공식 채널에서 확인해 주세요. 알림은 시작 5분 전에 울립니다." : "공식 편성표 · 시작 5분 전 알림. 앱을 열 때 오늘 일정과 알림을 갱신합니다. 편성은 변경될 수 있어요.")
            }
            if let message = schedule.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            if let station = selectedStation, let url = ChannelSchedule.officialURL(for: station) {
                Section { Link(destination: url) { Label("\(station.name) 공식 편성표", systemImage: "arrow.up.right") } }
            }
        }.scrollContentBackground(.hidden).background { LiquidRadioBackground() }.navigationTitle("오늘의 편성표").environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .task {
                let initial = stationKey ?? RadioPlayer.shared.station?.catalogKey ?? "cbsstandard"
                selectedKey = library.stations.contains { $0.catalogKey == initial } ? initial : library.stations.first?.catalogKey ?? "cbsstandard"
                await schedule.refresh()
            }.refreshable { await schedule.refresh(force: true) }
            .alert("방송 알림", isPresented: Binding(get: { reminders.message != nil }, set: { if !$0 { reminders.message = nil } })) { Button("확인") { reminders.message = nil } } message: { Text(reminders.message ?? "") }
    }
}
struct NewsBrowser: View {
    @Bindable var library: StationLibrary
    @State private var topic: NewsTopic = .all
    @State private var broadcaster = "전체"
    @State private var schedule = ProgramSchedule.shared
    @State private var reminders = ProgramReminders.shared
    private let broadcasters = ["전체", "CBS", "KBS", "YTN", "MBC", "SBS"]
    var programs: [RadioProgram] {
        schedule.programs.filter { $0.stationKey == "cbsstandard" && $0.topic != nil && (topic == .all || $0.topic == topic) && (broadcaster == "전체" || broadcaster == "CBS") }
    }
    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(NewsTopic.allCases) { value in Button(value.rawValue) { topic = value }.buttonStyle(.bordered).tint(topic == value ? RadioDesign.coral : .gray) } }
                }
                Picker("방송사", selection: $broadcaster) { ForEach(broadcasters, id: \.self) { Text($0).tag($0) } }
            }.listRowBackground(Color.clear)
            Section {
                ProgramList(programs: programs, library: library)
                if schedule.loading { ProgressView() }
                if programs.isEmpty && !schedule.loading { Text("이 분류의 프로그램 편성을 아직 확인하지 못했어요.").foregroundStyle(.secondary) }
            } header: { Text("오늘의 \(topic == .all ? "뉴스·시사" : topic.rawValue) 프로그램") } footer: { Text("프로그램 제목으로 분류합니다. 앱 내 편성은 현재 CBS를 지원해요.") }
            Section(topic == .local ? "지역 방송국으로 듣기" : "방송국으로 듣기") {
                ForEach(library.newsStations.filter { (broadcaster == "전체" || $0.name.uppercased().hasPrefix(broadcaster)) && (topic != .local || $0.newsRegion != nil) }) { station in
                    HStack {
                        Button { RadioPlayer.shared.play(station) } label: {
                            HStack { StationArtwork(station: station).frame(width: 48, height: 48); VStack(alignment: .leading) { Text(station.name).font(.headline); ConnectionBadge(station: station) } }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        Button { library.toggle(station) } label: { Image(systemName: library.favorites.contains { $0.catalogKey == station.catalogKey } ? "heart.fill" : "heart").frame(width: 44, height: 44) }.buttonStyle(.plain).tint(RadioDesign.coral).accessibilityLabel("즐겨찾기 변경")
                    }.contextMenu { Button("방송 연결 확인") { Task { await ConnectionHealth.shared.check(station, force: true) } } }
                }
            }
            NavigationLink("전체 편성표와 공식 방송사", destination: ScheduleView(library: library, stationKey: nil))
        }.scrollContentBackground(.hidden).background { LiquidRadioBackground() }.navigationTitle("뉴스·시사").environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .task { await schedule.refresh(); await ConnectionHealth.shared.check(Array(library.newsStations.prefix(3))) }
            .refreshable { await schedule.refresh(force: true); await library.refresh() }
            .alert("방송 알림", isPresented: Binding(get: { reminders.message != nil }, set: { if !$0 { reminders.message = nil } })) { Button("확인") { reminders.message = nil } } message: { Text(reminders.message ?? "") }
    }
}
struct PresetStrip: View {
    @State private var presets = RadioPresets.shared
    var body: some View {
        HStack(spacing: 10) {
            ForEach(RadioPresetKind.allCases) { kind in
                if let preset = presets.values.first(where: { $0.kind == kind }) {
                    Button { presets.play(preset) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: kind.icon).font(.title2)
                            Text(kind.title).font(.subheadline.bold())
                            Text(preset.station.name).font(.caption2).lineLimit(1)
                            if let minutes = preset.sleepMinutes { Text("\(minutes)분 후 끄기").font(.caption2) }
                        }.frame(maxWidth: .infinity, minHeight: 96, alignment: .leading).padding(14).background(RadioDesign.coral.opacity(0.08), in: .rect(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityLabel("\(kind.title) · \(preset.station.name) 재생")
                }
            }
        }
    }
}
struct PresetEditor: View {
    let kind: RadioPresetKind
    @Bindable var library: StationLibrary
    @State private var stationID = ""
    @State private var minutes = 0
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Picker("방송", selection: $stationID) { ForEach(library.stations) { Text($0.name).tag($0.id) } }
            Picker("자동 종료", selection: $minutes) { Text("계속 듣기").tag(0); ForEach([15, 30, 45, 60, 90], id: \.self) { Text("\($0)분 후 끄기").tag($0) } }
            Section { Text("프리셋을 누르면 저장한 방송과 타이머를 함께 실행해요.").font(.footnote) }
            Button("저장") {
                if let station = library.stations.first(where: { $0.id == stationID }) { RadioPresets.shared.update(.init(kind: kind, station: station, sleepMinutes: minutes == 0 ? nil : minutes)); dismiss() }
            }.disabled(stationID.isEmpty)
        }.navigationTitle("\(kind.title) 라디오")
            .onAppear { if let preset = RadioPresets.shared.values.first(where: { $0.kind == kind }) { stationID = preset.station.id; minutes = preset.sleepMinutes ?? 0 } }
    }
}

#if DEBUG
struct RadioWidgetPreview: View {
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-showPanel") {
            RadioPanelView(entry: .init(date: .now, snapshot: SharedStore.read())).frame(width: 340, height: 580).padding().background { LiquidRadioBackground() }
        } else {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
        VStack(spacing: 24) {
            Text("나의 주파수 · 위젯 미리보기").font(.title2.bold())
            RadioWidgetView(entry: RadioEntry(date: .now, snapshot: SharedStore.read()), familyOverride: .systemSmall)
                .frame(width: 170, height: 170).padding(16).background(.white, in: .rect(cornerRadius: 28))
            Text("침대 옆 라디오 · 스탠바이").font(.headline)
            RadioWidgetView(entry: RadioEntry(date: .now, snapshot: SharedStore.read(), choice: .bedtime, night: true), familyOverride: .systemSmall)
                .frame(width: 170, height: 170).padding(16).background(Color(red: 0.055, green: 0.065, blue: 0.085), in: .rect(cornerRadius: 28))
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background { LiquidRadioBackground() }
        }
        }
    }
}
#endif

/// 플레이어의 '지금 나오는 곡' 한 줄. 누르면 오늘 이 프로그램의 선곡표를 엽니다.
struct NowPlayingSongRow: View {
    let station: Station
    @State private var showList = false
    private var songs: NowPlayingSongs { .shared }
    var body: some View {
        if SongFeed.supports(station) {
            TimelineView(.periodic(from: .now, by: 20)) { context in
                let board = songs.board(for: station)
                let current = board?.current(at: context.date)
                Button { showList = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: current == nil ? "music.note.list" : "music.note")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(LiquidRadioTheme.accent)
                            .symbolEffect(.variableColor.iterative, isActive: current != nil && RadioPlayer.shared.isPlaying)
                        if let current {
                            Text(current.title).fontWeight(.semibold).lineLimit(1)
                            if !current.artist.isEmpty { Text(current.artist).foregroundStyle(.secondary).lineLimit(1) }
                        } else {
                            Text(board == nil ? "곡 정보를 불러오는 중" : (board?.songs.isEmpty == false ? "지금은 이야기 중 · 선곡표 보기" : "선곡표 보기"))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(current.map { "지금 나오는 곡, \($0.title), \($0.artist). 선곡표 열기" } ?? "선곡표 열기")
            }
            .task(id: station.catalogKey) {
                await songs.refresh(station)
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-showSongs") || ProcessInfo.processInfo.arguments.contains("-showPlaylistBuilder") { showList = true }
                #endif
            }
            .sheet(isPresented: $showList) { SongListSheet(station: station).presentationDetents([.medium, .large]) }
        }
    }
}

struct SongListSheet: View {
    let station: Station
    @Environment(\.dismiss) private var dismiss
    @State private var showPlaylist = false
    @State private var opening: String?
    @Environment(\.openURL) private var openURL
    private var songs: NowPlayingSongs { .shared }
    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.timeZone = TimeZone(identifier: "Asia/Seoul"); f.dateFormat = "a h:mm"; return f
    }()
    var body: some View {
        NavigationStack {
            let board = songs.board(for: station)
            List {
                if let board, !board.songs.isEmpty {
                    let current = board.current()
                    Section {
                        ForEach(board.songs) { song in
                            Button { open(song) } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: song.albumImage) { image in image.resizable().scaledToFill() } placeholder: {
                                    Image(systemName: "music.note").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary)
                                }
                                .frame(width: 44, height: 44).clipShape(.rect(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title).font(.body.weight(song == current ? .semibold : .regular)).lineLimit(2)
                                    if !song.artist.isEmpty { Text(song.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                                }
                                Spacer(minLength: 8)
                                if song == current { Text("지금").font(.caption.weight(.bold)).foregroundStyle(LiquidRadioTheme.accent) }
                                else if let played = song.playedAt { Text(Self.clock.string(from: played)).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
                                if opening == song.id { ProgressView().controlSize(.small) }
                                else { Image(systemName: "arrow.up.forward.app").font(.footnote).foregroundStyle(.tertiary) }
                            }
                            .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Apple Music에서 이 곡을 찾아요")
                        }
                    } header: {
                        Text(board.program.map { "\($0) · 오늘 선곡" } ?? "오늘 선곡")
                    } footer: {
                        Text("곡을 누르면 Apple Music에서 찾아요. 방송사 공개 선곡 정보라 실제 방송과 조금 다를 수 있어요.")
                    }
                } else if songs.loading.contains(station.catalogKey) || board == nil {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView("아직 선곡 정보가 없어요", systemImage: "music.note.list", description: Text("이야기·뉴스 프로그램이거나 방송사가 선곡을 아직 올리지 않았어요."))
                }
            }
            .navigationTitle(station.name + " 선곡표")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
                if let board, !board.songs.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showPlaylist = true } label: { Label("플레이리스트로 만들기", systemImage: "text.badge.plus") }
                    }
                }
            }
            .sheet(isPresented: $showPlaylist) {
                if let board { PlaylistBuilderSheet(station: station, board: board) }
            }
            .refreshable { await songs.refresh(station, force: true) }
            .task {
                await songs.refresh(station)
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-showPlaylistBuilder") { showPlaylist = true }
                #endif
            }
        }
    }
}

// MARK: - Apple Music 연결 · 플레이리스트

extension SongListSheet {
    /// 곡을 먼저 Apple Music 카탈로그에서 찾아 그 곡 페이지로 바로 엽니다. 못 찾으면 검색으로 엽니다.
    fileprivate func open(_ song: RadioSong) {
        guard opening == nil else { return }
        opening = song.id
        Task {
            let match = await SongMatcher.match(song)
            opening = nil
            openURL(match.confident ? (match.songURL ?? AppleMusicLink.search(song)) : AppleMusicLink.search(song))
        }
    }
}

enum AppleMusicLink {
    /// Apple Music 앱의 검색 결과로 엽니다(설치되어 있으면 앱, 아니면 웹).
    static func search(_ song: RadioSong) -> URL {
        // "(Feat. …)", "(Inst.)" 같은 꼬리표는 검색을 방해해서 뗍니다.
        let title = song.title.components(separatedBy: CharacterSet(charactersIn: "(（[")).first?.trimmingCharacters(in: .whitespaces) ?? song.title
        var parts = URLComponents(string: "https://music.apple.com/kr/search")!
        parts.queryItems = [.init(name: "term", value: [title.isEmpty ? song.title : title, song.artist].filter { !$0.isEmpty }.joined(separator: " "))]
        return parts.url!
    }
}

struct MusicMatch: Identifiable, Sendable {
    let song: RadioSong
    var trackID: String?
    var foundTitle: String?
    var foundArtist: String?
    var artwork: URL?
    var url: URL?
    var confident = false
    var id: String { song.id }
    /// 미국 스토어에서 찾은 곡 번호는 한국 스토어에서도 같아서, 한국 Apple Music 곡 페이지로 엽니다.
    var songURL: URL? { trackID.flatMap { URL(string: "https://music.apple.com/kr/song/\($0)") } }
}

enum SongMatcher {
    private struct Response: Decodable {
        struct Item: Decodable { let trackId: Int?; let trackName: String?; let artistName: String?; let artworkUrl100: String?; let trackViewUrl: String? }
        let results: [Item]
    }
    static func normalize(_ text: String) -> String {
        let base = text.lowercased().components(separatedBy: CharacterSet(charactersIn: "(（[")).first ?? text
        return base.filter { $0.isLetter || $0.isNumber }
    }
    /// Apple 공개 검색 API(키 없음)로 곡을 찾습니다. 한국 스토어는 곡 검색 결과를 주지 않아 미국 스토어를 씁니다.
    /// 제목과 가수가 모두 맞을 때만 '정확'으로 표시합니다.
    static func match(_ song: RadioSong) async -> MusicMatch {
        var result = MusicMatch(song: song)
        var parts = URLComponents(string: "https://itunes.apple.com/search")!
        parts.queryItems = [.init(name: "term", value: "\(song.artist) \(song.title)"), .init(name: "country", value: "US"), .init(name: "entity", value: "song"), .init(name: "limit", value: "8")]
        guard let url = parts.url, let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let items = try? JSONDecoder().decode(Response.self, from: data).results, !items.isEmpty else { return result }
        let title = normalize(song.title), artist = normalize(song.artist)
        func titleMatches(_ item: Response.Item) -> Bool {
            let found = normalize(item.trackName ?? "")
            return !title.isEmpty && !found.isEmpty && (found == title || (min(found.count, title.count) >= 3 && (found.hasPrefix(title) || title.hasPrefix(found))))
        }
        func artistMatches(_ item: Response.Item) -> Bool {
            let found = normalize(item.artistName ?? "")
            return !artist.isEmpty && !found.isEmpty && (found.contains(artist) || artist.contains(found))
        }
        // Apple Music은 한국 가수 이름을 영문으로 적는 경우가 많습니다(박혜경 → Park Hye Kyung).
        // 가수 이름으로 함께 검색했으므로, 제목이 같고 표기 문자만 다르면 같은 가수로 봅니다.
        func hasHangul(_ text: String) -> Bool { text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) } }
        func artistCompatible(_ item: Response.Item) -> Bool {
            artistMatches(item) || (hasHangul(song.artist) && !hasHangul(item.artistName ?? "") && normalize(item.trackName ?? "") == title)
        }
        let upper = song.title.uppercased()
        let instrumental = ["(INST", "(MR", "INSTRUMENTAL", "(BGM"].contains { upper.contains($0) }
        let best = items.first { titleMatches($0) && artistMatches($0) } ?? items.first { titleMatches($0) && artistCompatible($0) } ?? items.first { titleMatches($0) } ?? items.first!
        result.trackID = best.trackId.map(String.init)
        result.foundTitle = best.trackName
        result.foundArtist = best.artistName
        result.artwork = best.artworkUrl100.flatMap(URL.init(string:))
        result.url = best.trackViewUrl.flatMap(URL.init(string:))
        result.confident = !instrumental && titleMatches(best) && artistCompatible(best)
        return result
    }
}

enum AppleMusicPlaylist {
    enum Failure: LocalizedError {
        case denied, creation
        var errorDescription: String? {
            switch self {
            case .denied: "Apple Music 접근이 허용되지 않았어요. 설정 → 온에어 → 미디어 및 Apple Music을 켜 주세요."
            case .creation: "플레이리스트를 만들지 못했어요. Apple Music 구독과 iCloud 음악 보관함이 켜져 있는지 확인해 주세요."
            }
        }
    }
    /// Apple Music 보관함에 플레이리스트를 만들고 곡을 담습니다. 담은 곡 수를 돌려줍니다.
    @MainActor static func create(name: String, productIDs: [String]) async throws -> Int {
        let status: MPMediaLibraryAuthorizationStatus = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw Failure.denied }
        let metadata = MPMediaPlaylistCreationMetadata(name: name)
        metadata.descriptionText = "온에어 라디오에서 들은 곡"
        nonisolated(unsafe) var created: MPMediaPlaylist?
        created = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MPMediaPlaylist, Error>) in
            MPMediaLibrary.default().getPlaylist(with: UUID(), creationMetadata: metadata) { playlist, error in
                if let playlist { continuation.resume(returning: playlist) } else { continuation.resume(throwing: error ?? Failure.creation) }
            }
        }
        guard let playlist = created else { throw Failure.creation }
        var added = 0
        for id in productIDs {
            let ok: Bool = await withCheckedContinuation { continuation in
                playlist.addItem(withProductID: id) { error in continuation.resume(returning: error == nil) }
            }
            if ok { added += 1 }
        }
        return added
    }
}

struct PlaylistBuilderSheet: View {
    let station: Station
    let board: SongBoard
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var matches: [MusicMatch] = []
    @State private var selected: Set<String> = []
    @State private var matching = true
    @State private var saving = false
    @State private var name = ""
    @State private var result: String?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("플레이리스트 이름", text: $name)
                } footer: {
                    Text("Apple Music 구독이 필요해요. '정확'으로 찾은 곡만 미리 골라 두었어요. '확인 필요'는 눌러서 맞는지 본 뒤 담으세요.")
                }
                Section {
                    if matching && matches.count < board.songs.count {
                        HStack(spacing: 10) { ProgressView(); Text("Apple Music에서 찾는 중 \(matches.count)/\(board.songs.count)").foregroundStyle(.secondary) }
                    }
                    ForEach(matches) { match in row(match) }
                } header: {
                    Text("\(selected.count)곡 선택")
                }
            }
            .navigationTitle("플레이리스트 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: { if saving { ProgressView() } else { Text("만들기").bold() } }
                        .disabled(selected.isEmpty || saving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("플레이리스트를 만들었어요", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                Button("Apple Music 열기") { openURL(URL(string: "music://")!); dismiss() }
                Button("확인") { dismiss() }
            } message: { Text(result ?? "") }
            .alert("만들지 못했어요", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("확인") { failure = nil }
            } message: { Text(failure ?? "") }
            .task {
                guard matches.isEmpty else { return }
                name = "온에어 · \(station.name) · " + Date.now.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR")))
                // 공개 API 이용 한도를 지키려고 한 곡씩, 최대 25곡을 찾습니다(오래된 곡부터).
                for song in board.songs.prefix(25).reversed() {
                    let match = await SongMatcher.match(song)
                    matches.append(match)
                    if match.confident, let id = match.trackID { selected.insert(id) }
                    try? await Task.sleep(for: .milliseconds(250))
                }
                matching = false
            }
        }
    }

    private func row(_ match: MusicMatch) -> some View {
        let id = match.trackID
        let isOn = id.map { selected.contains($0) } ?? false
        return HStack(spacing: 12) {
            Button {
                guard let id else { return }
                if isOn { selected.remove(id) } else { selected.insert(id) }
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(isOn ? LiquidRadioTheme.accent : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain).disabled(id == nil)
            .accessibilityLabel(isOn ? "\(match.song.title) 빼기" : "\(match.song.title) 담기")
            AsyncImage(url: match.artwork) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.15) }
                .frame(width: 44, height: 44).clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(match.song.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(match.song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let title = match.foundTitle {
                    HStack(spacing: 4) {
                        Text(match.confident ? "정확" : "확인 필요")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(match.confident ? LiquidRadioTheme.accent : .orange)
                        Text("→ \(title) · \(match.foundArtist ?? "")").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("Apple Music에서 찾지 못했어요").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let url = match.songURL ?? match.url {
                Button { openURL(url) } label: { Image(systemName: "arrow.up.forward.app").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Apple Music에서 이 곡 보기")
            }
        }
    }

    private func save() async {
        saving = true; defer { saving = false }
        // 방송 순서대로 담습니다.
        let ids = matches.compactMap(\.trackID).filter { selected.contains($0) }
        do {
            let added = try await AppleMusicPlaylist.create(name: name.trimmingCharacters(in: .whitespaces), productIDs: ids)
            result = added == ids.count ? "\(added)곡을 '\(name)'에 담았어요." : "\(ids.count)곡 중 \(added)곡을 담았어요. 나머지는 Apple Music에 없는 곡이에요."
        } catch {
            failure = error.localizedDescription
        }
    }
}
