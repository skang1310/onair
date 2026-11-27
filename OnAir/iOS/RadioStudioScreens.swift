import SwiftUI

// MARK: - 디자인 토큰
// 탭은 LIVE · 편성 · 마이 세 개. 채널은 LIVE에서 한 번씩만 보여 줍니다.

enum ChannelBrand {
    /// 방송사별 카드 배경. 방송사 색을 참고하되 흰 글씨가 잘 읽히도록 어둡게 잡았습니다.
    static func colors(for station: Station) -> [Color] {
        let key = station.catalogKey
        if key.hasPrefix("kbs") { return [Color(red: 0.16, green: 0.36, blue: 0.86), Color(red: 0.06, green: 0.17, blue: 0.48)] }
        if key.hasPrefix("mbc") { return [Color(red: 0.20, green: 0.23, blue: 0.34), Color(red: 0.07, green: 0.08, blue: 0.14)] }
        if key.hasPrefix("sbs") { return [Color(red: 0.05, green: 0.52, blue: 0.70), Color(red: 0.03, green: 0.25, blue: 0.42)] }
        if key.hasPrefix("ebs") { return [Color(red: 0.18, green: 0.62, blue: 0.40), Color(red: 0.06, green: 0.32, blue: 0.22)] }
        if key.hasPrefix("cbs") { return [Color(red: 0.84, green: 0.27, blue: 0.27), Color(red: 0.45, green: 0.09, blue: 0.16)] }
        if key == "ytnradio" { return [Color(red: 0.93, green: 0.42, blue: 0.16), Color(red: 0.56, green: 0.17, blue: 0.08)] }
        return LiquidRadioTheme.colors(station.palette)
    }
    /// 어두운 배경 위 얇은 막대용 색. 비텍스트 대비 3:1 이상이 되도록 밝힙니다.
    static func bar(for station: Station) -> Color {
        if station.catalogKey.hasPrefix("mbc") { return Color(red: 0.62, green: 0.66, blue: 0.86) }
        if station.catalogKey.hasPrefix("kbs") { return Color(red: 0.36, green: 0.55, blue: 1.0) }
        return colors(for: station)[0]
    }
}

/// 채널의 '지금' 한 줄: 재생 중이면 곡, 아니면 현재 프로그램.
@MainActor func channelNowLine(_ station: Station, at date: Date = .now) -> String? {
    let player = RadioPlayer.shared
    if player.station?.catalogKey == station.catalogKey, player.isPlaying || player.buffering, let song = NowPlayingSongs.shared.current(for: station, at: date) {
        return song.artist.isEmpty ? song.title : "\(song.title) · \(song.artist)"
    }
    return ProgramSchedule.shared.current(for: station, at: date)?.title ?? NowPlayingSongs.shared.board(for: station)?.program
}

// MARK: - 라디오 (주파수 다이얼)
// 차량 라디오의 프리셋 목록처럼 주파수를 앞세운 한 줄 리스트. 채널은 한 번씩만 나옵니다.

struct LiveChannelsScreen: View {
    @Bindable var library: StationLibrary
    var openPlayer: () -> Void
    @State private var player = RadioPlayer.shared
    @State private var weather = RadioWeatherModel.shared

    private var favoriteKeys: Set<String> { Set(library.favorites.map(\.catalogKey)) }
    private var favorites: [Station] { library.favorites }
    private var terrestrial: [Station] {
        Station.terrestrialKeys.compactMap { key in library.stations.first { $0.catalogKey == key } }
            .filter { !favoriteKeys.contains($0.catalogKey) }
            .sorted { (RadioFrequency.values[$0.catalogKey] ?? 0) < (RadioFrequency.values[$1.catalogKey] ?? 0) }
    }
    private var others: [Station] { library.stations.filter { !$0.isTerrestrial && !favoriteKeys.contains($0.catalogKey) } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                header
                group("내 프리셋", icon: "star.fill", favorites, caption: favorites.count > 1 ? "길게 눌러 순서 바꾸기" : nil, reorderable: true)
                group("지상파 FM", icon: "dot.radiowaves.left.and.right", terrestrial, caption: "주파수 순")
                group("인터넷 · 지역 라디오", icon: "globe.asia.australia", others)
                if let message = library.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 18).padding(.bottom, 28)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background { LiquidRadioBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await library.refresh(); await ProgramSchedule.shared.refresh(force: true) }
        .task {
            // '지금 방송' 줄을 채웁니다. 채널마다 30초 캐시.
            for station in library.stations where SongFeed.supports(station) { await NowPlayingSongs.shared.refresh(station) }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                    if let now = weather.weather { Text("·"); Image(systemName: now.symbol).symbolRenderingMode(.multicolor); Text(now.temperatureLabel) }
                }
                .font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                Text("온에어").font(.system(size: 34, weight: .heavy, design: .rounded)).tracking(-1)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder private func group(_ title: String, icon: String, _ stations: [Station], caption: String? = nil, reorderable: Bool = false) -> some View {
        if !stations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(LiquidRadioTheme.accent)
                    Text(title).font(.subheadline.weight(.bold))
                    if let caption { Text(caption).font(.caption).foregroundStyle(.tertiary) }
                    Spacer()
                    Text("\(stations.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                rows(stations, reorderable: reorderable)
                .background(OnAirTokens.card)
                .clipShape(.rect(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(OnAirTokens.border.opacity(0.45), lineWidth: 1))
            }
        }
    }

    @ViewBuilder private func rows(_ stations: [Station], reorderable: Bool) -> some View {
        let last = stations.last?.id
        let content = ForEach(stations) { station in
            ChannelDialRow(station: station,
                           favorite: favoriteKeys.contains(station.catalogKey),
                           play: { play(station) },
                           toggleFavorite: { withAnimation(.snappy) { library.toggle(station) } })
                .overlay(alignment: .bottom) { if station.id != last { Divider().padding(.leading, 96) } }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button { withAnimation(.snappy) { library.toggle(station) } } label: {
                        Label(favoriteKeys.contains(station.catalogKey) ? "프리셋 빼기" : "프리셋 담기", systemImage: favoriteKeys.contains(station.catalogKey) ? "star.slash" : "star")
                    }
                    .tint(favoriteKeys.contains(station.catalogKey) ? .gray : OnAirTokens.secondary)
                }
        }
        if #available(iOS 27.0, *) {
            // iOS 27: 리스트가 아닌 컨테이너에서도 스와이프 액션 · 프리셋은 바로 끌어서 순서 변경
            if reorderable {
                VStack(spacing: 0) { content.reorderable() }
                    .reorderContainer(for: Station.self) { difference in
                        let target: String? = { if case .before(let id) = difference.destination.position { return id }; return nil }()
                        withAnimation(.snappy) { library.moveFavorites(ids: difference.sources, before: target) }
                    }
                    .swipeActionsContainer()
            } else {
                VStack(spacing: 0) { content }.swipeActionsContainer()
            }
        } else {
            VStack(spacing: 0) { content }
        }
    }

    private func play(_ station: Station) {
        if player.station?.catalogKey == station.catalogKey {
            if !player.isPlaying && !player.buffering { player.play(station) }
            openPlayer()
        } else { player.play(station) }
    }
}

struct ChannelDialRow: View {
    let station: Station
    let favorite: Bool
    let play: () -> Void
    let toggleFavorite: () -> Void
    @State private var player = RadioPlayer.shared
    private var active: Bool { player.station?.catalogKey == station.catalogKey && (player.isPlaying || player.buffering) }
    private var frequency: String { RadioFrequency.label(station) }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: play) {
                HStack(spacing: 14) {
                    // 주파수 다이얼 숫자
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(frequency == "LIVE" ? "WEB" : frequency)
                            .font(.system(size: frequency == "LIVE" ? 17 : 24, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .tracking(-0.5)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(active ? LiquidRadioTheme.accent : .primary)
                            .shadow(color: active ? LiquidRadioTheme.accent.opacity(0.55) : .clear, radius: 8)
                        Text(frequency == "LIVE" ? "STREAM" : "MHz")
                            .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                            .foregroundStyle(OnAirTokens.mutedForeground)
                    }
                    .frame(width: 66, alignment: .trailing)
                    Capsule().fill(ChannelBrand.bar(for: station)).frame(width: 3, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(station.name).font(.body.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            HStack(spacing: 5) {
                                if active {
                                    Image(systemName: "waveform").font(.caption2.weight(.bold)).foregroundStyle(LiquidRadioTheme.accent)
                                        .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                                }
                                Text(channelNowLine(station, at: context.date) ?? (station.catalogKey == "ebsfm" ? "교육 · 외국어" : station.category)).lineLimit(1)
                            }
                            .font(.footnote).foregroundStyle(active ? LiquidRadioTheme.accent : OnAirTokens.mutedForeground)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12).padding(.leading, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(station.name) \(frequency == "LIVE" ? "" : "FM \(frequency)") 재생")
            .accessibilityIdentifier("station-play-\(station.catalogKey)")
            Button(action: toggleFavorite) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(favorite ? LiquidRadioTheme.accent : Color.secondary.opacity(0.6))
                    .frame(width: 48, height: 48).contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favorite ? "\(station.name) 프리셋에서 빼기" : "\(station.name) 프리셋에 담기")
            .accessibilityIdentifier("station-favorite-\(station.catalogKey)")
        }
        .background(active ? LiquidRadioTheme.accent.opacity(0.10) : .clear)
        .contextMenu {
            Button("방송 연결 확인", systemImage: "antenna.radiowaves.left.and.right") { Task { await ConnectionHealth.shared.check(station, force: true) } }
            if let url = station.homepageURL { Link(destination: url) { Label("방송사 홈페이지", systemImage: "safari") } }
        }
    }
}

// MARK: - 검색

struct RadioSearchSheet: View {
    @Bindable var library: StationLibrary
    var openPlayer: () -> Void
    /// 탭 바의 검색 탭(Tab(role: .search))으로 쓸 때는 닫기 버튼 없이 표시합니다.
    var inTab = false
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var text: String { query.trimmingCharacters(in: .whitespaces) }
    private var channels: [Station] {
        guard !text.isEmpty else { return [] }
        return library.stations.filter { $0.name.localizedCaseInsensitiveContains(text) || RadioFrequency.label($0).contains(text) }
    }
    private var onAirNow: [(station: Station, program: String)] {
        Station.terrestrialKeys.compactMap { key in library.stations.first { $0.catalogKey == key } }
            .sorted { (RadioFrequency.values[$0.catalogKey] ?? 999) < (RadioFrequency.values[$1.catalogKey] ?? 999) }
            .compactMap { station in channelNowLine(station).map { (station, $0) } }
    }
    private var programs: [RadioProgram] {
        guard !text.isEmpty else { return [] }
        return ProgramSchedule.shared.programs.filter { $0.title.localizedCaseInsensitiveContains(text) && $0.endsAt > .now }.prefix(30).map { $0 }
    }
    var body: some View {
        NavigationStack {
            List {
                if text.isEmpty {
                    // 빈 검색 화면 대신, 지금 각 채널에서 나오는 프로그램을 바로 틀 수 있게 보여 줍니다.
                    Section {
                        ForEach(onAirNow, id: \.station.id) { item in
                            Button { play(item.station) } label: {
                                HStack(spacing: 12) {
                                    Text(RadioFrequency.label(item.station)).font(.system(.callout, design: .rounded).weight(.light)).monospacedDigit()
                                        .frame(width: 48, alignment: .trailing).foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.program).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                        Text(item.station.name).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.fill").font(.footnote).foregroundStyle(LiquidRadioTheme.accent)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.station.name), \(item.program) 듣기")
                        }
                    } header: {
                        Text("지금 방송 중")
                    } footer: {
                        Text("채널 이름, 주파수(예: 89.1), 오늘 프로그램 이름으로 찾을 수 있어요.")
                    }
                    .listRowBackground(OnAirTokens.card)
                }
                if !channels.isEmpty {
                    Section("채널 \(channels.count)") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(channels) { station in
                                    Button { play(station) } label: {
                                        VStack(spacing: 6) {
                                            LiquidStationMark(station: station, size: 64)
                                            Text(station.name).font(.caption.weight(.semibold)).lineLimit(1)
                                            Text(RadioFrequency.label(station) == "LIVE" ? "인터넷" : RadioFrequency.label(station) + "MHz").font(.caption2).foregroundStyle(.secondary)
                                        }.frame(width: 80)
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(OnAirTokens.card)
                }
                if !programs.isEmpty {
                    Section("오늘의 프로그램 \(programs.count)") {
                        ForEach(programs) { program in
                            let station = library.stations.first { $0.catalogKey == program.stationKey }
                            Button { if let station { play(station) } } label: {
                                HStack(spacing: 12) {
                                    if let station { LiquidStationMark(station: station, size: 40) }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(program.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        HStack(spacing: 4) {
                                            Text(station?.name ?? program.stationKey)
                                            Text("·"); Text(program.startsAt, style: .time)
                                            if program.isLive(at: .now) { Text("방송 중").foregroundStyle(LiquidRadioTheme.accent) }
                                        }.font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle").foregroundStyle(LiquidRadioTheme.accent)
                                }
                            }
                        }
                    }
                    .listRowBackground(OnAirTokens.card)
                }
                if !text.isEmpty && channels.isEmpty && programs.isEmpty { ContentUnavailableView.search(text: text) }
            }
            .environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .navigationTitle("검색").navigationBarTitleDisplayMode(inTab ? .large : .inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "채널, 프로그램 검색")
            .toolbar { if !inTab { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } } }
            .scrollContentBackground(.hidden)
            .background { LiquidRadioBackground() }
        }
    }
    private func play(_ station: Station) {
        RadioPlayer.shared.play(station)
        if !inTab { dismiss() }
        Task { try? await Task.sleep(for: .milliseconds(350)); openPlayer() }
    }
}

// MARK: - 편성

struct ScheduleTabScreen: View {
    @Bindable var library: StationLibrary
    @State private var selectedKey = ""
    @State private var schedule = ProgramSchedule.shared
    @State private var reminders = ProgramReminders.shared
    private var channels: [Station] {
        (Station.terrestrialKeys + ["ytnradio", "mbcallthat"]).compactMap { key in library.stations.first { $0.catalogKey == key } }
            .sorted { (RadioFrequency.values[$0.catalogKey] ?? 999) < (RadioFrequency.values[$1.catalogKey] ?? 999) }
    }
    private var selected: Station? { channels.first { $0.catalogKey == selectedKey } }
    /// KBS처럼 30분 단위로 같은 프로그램을 나눠 보내는 편성을 한 줄로 합칩니다.
    /// 5분이 안 되는 캠페인·짧은 뉴스는 목록을 끊어 놓기만 해서 빼고(지금 방송 중이면 남김),
    /// 그 앞뒤로 이어지는 같은 프로그램은 한 줄로 이어 붙입니다.
    private var programs: [RadioProgram] {
        var merged: [RadioProgram] = []
        let now = Date.now
        for program in schedule.programs where program.stationKey == selectedKey {
            let isFiller = program.endsAt.timeIntervalSince(program.startsAt) < 300 && !(program.startsAt...program.endsAt).contains(now)
            if isFiller { continue }
            if let last = merged.last, last.title == program.title, abs(last.endsAt.timeIntervalSince(program.startsAt)) < 120 {
                merged[merged.count - 1] = RadioProgram(stationKey: last.stationKey, title: last.title, startsAt: last.startsAt, endsAt: max(last.endsAt, program.endsAt), source: last.source)
            } else { merged.append(program) }
        }
        return merged
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    if programs.isEmpty {
                        if schedule.loading { HStack { Spacer(); ProgressView(); Spacer() } }
                        else {
                            ContentUnavailableView {
                                Label("편성표를 앱에서 볼 수 없어요", systemImage: "calendar")
                            } description: {
                                Text(NowPlayingSongs.shared.board(for: selected ?? .preview)?.program.map { "지금 방송: \($0)" } ?? "방송사 공식 편성표에서 확인해 주세요.")
                            } actions: {
                                if let station = selected, let url = ChannelSchedule.officialURL(for: station) { Link("공식 편성표 열기", destination: url) }
                            }
                        }
                    }
                    ForEach(programs) { program in
                        ProgramRow(program: program, station: selected, reminders: reminders).id(program.id)
                    }
                } header: {
                    HStack {
                        Text(Date.now, format: .dateTime.month().day().weekday())
                        Spacer()
                        if let station = selected, let url = ChannelSchedule.officialURL(for: station) { Link("공식 편성표", destination: url).font(.caption) }
                    }
                } footer: {
                    if !programs.isEmpty { Text("벨을 누르면 시작 5분 전에 알려 드려요. 편성은 방송사 사정으로 바뀔 수 있어요.") }
                }
                if let message = schedule.message { Text(message).font(.footnote).foregroundStyle(.secondary).listRowBackground(Color.clear) }
            }
            .scrollContentBackground(.hidden)
            .background { LiquidRadioBackground() }
            .safeAreaInset(edge: .top, spacing: 0) {
                // 콘텐츠 위에 떠 있는 Liquid Glass 채널 선택 바
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(channels) { station in
                                let chosen = selectedKey == station.catalogKey
                                Button { withAnimation(.snappy) { selectedKey = station.catalogKey } } label: {
                                    HStack(spacing: 6) {
                                        Text(RadioFrequency.label(station) == "LIVE" ? "WEB" : RadioFrequency.label(station))
                                            .font(.system(.subheadline, design: .rounded).weight(.light)).monospacedDigit()
                                        Text(shortName(station)).font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 14).frame(height: 44)
                                    .foregroundStyle(chosen ? Color.white : .primary)
                                    .glassEffect(chosen ? .regular.tint(OnAirTokens.secondary).interactive() : .regular.interactive(), in: .capsule)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(station.name)
                                .accessibilityAddTraits(chosen ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                }
                .scrollClipDisabled()
                // 칩 사이로 아래 글자가 비쳐 보이지 않게 배경색으로 살짝 덮습니다.
                .background {
                    LinearGradient(stops: [.init(color: OnAirTokens.background, location: 0), .init(color: OnAirTokens.background.opacity(0.92), location: 0.7), .init(color: OnAirTokens.background.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                        .padding(.bottom, -12).ignoresSafeArea(edges: .top)
                }
            }
            .navigationTitle("편성표")
            .environment(\.timeZone, CBSProgramParser.calendar.timeZone)
            .task {
                if selectedKey.isEmpty {
                    let current = RadioPlayer.shared.station?.catalogKey
                    selectedKey = channels.contains { $0.catalogKey == current } ? current! : channels.first?.catalogKey ?? "cbsstandard"
                }
                await schedule.refresh()
                if let selected { await NowPlayingSongs.shared.refresh(selected) }
                scrollToLive(proxy)
            }
            .onChange(of: selectedKey) { _, _ in
                scrollToLive(proxy)
                if let selected { Task { await NowPlayingSongs.shared.refresh(selected) } }
            }
            .refreshable { await schedule.refresh(force: true) }
            .alert("방송 알림", isPresented: Binding(get: { reminders.message != nil }, set: { if !$0 { reminders.message = nil } })) { Button("확인") { reminders.message = nil } } message: { Text(reminders.message ?? "") }
        }
    }
    private func shortName(_ station: Station) -> String {
        ["KBS ", "MBC ", "SBS ", "CBS "].reduce(station.name) { $0.replacingOccurrences(of: $1, with: "") }
    }
    private func scrollToLive(_ proxy: ScrollViewProxy) {
        guard let live = programs.first(where: { $0.isLive(at: .now) }) ?? programs.first(where: { $0.startsAt > .now }) else { return }
        Task { try? await Task.sleep(for: .milliseconds(150)); withAnimation { proxy.scrollTo(live.id, anchor: .center) } }
    }
}

private struct ProgramRow: View {
    let program: RadioProgram
    let station: Station?
    @Bindable var reminders: ProgramReminders
    var body: some View {
        let live = program.isLive(at: .now)
        let past = program.endsAt <= .now
        HStack(spacing: 14) {
            Text(program.startsAt, style: .time)
                .font(.subheadline.monospacedDigit().weight(live ? .bold : .regular))
                .foregroundStyle(live ? LiquidRadioTheme.accent : .secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 70, alignment: .leading)
            ZStack {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1.5).padding(.vertical, -14)
                Circle().fill(live ? LiquidRadioTheme.accent : past ? Color.primary.opacity(0.15) : OnAirTokens.card)
                    .frame(width: live ? 12 : 8, height: live ? 12 : 8)
                    .overlay(Circle().strokeBorder(live ? LiquidRadioTheme.accent.opacity(0.3) : Color.primary.opacity(0.25), lineWidth: live ? 4 : 1.5).padding(live ? -4 : 0))
            }
            .frame(width: 14)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(program.title).font(.body.weight(live ? .semibold : .regular)).lineLimit(2)
                }
                if live { Text("ON AIR · \(program.endsAt, style: .time)까지").font(.caption.weight(.semibold)).foregroundStyle(LiquidRadioTheme.accent) }
                else if !past, program.startsAt.timeIntervalSinceNow < 3600 { Text("\(max(1, Int(program.startsAt.timeIntervalSinceNow / 60)))분 후 시작").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 4)
            if live, let station {
                Button { RadioPlayer.shared.play(station) } label: {
                    Image(systemName: "play.fill").font(.footnote.bold()).foregroundStyle(OnAirTokens.onAccent).frame(width: 34, height: 34)
                }
                .buttonStyle(.glassProminent).buttonBorderShape(.circle).tint(LiquidRadioTheme.accent)
                .accessibilityLabel("\(program.title) 듣기")
            } else if !past {
                Button { Task { await reminders.toggle(program) } } label: {
                    Image(systemName: reminders.followed.contains(program.followKey) ? "bell.fill" : "bell")
                        .foregroundStyle(reminders.followed.contains(program.followKey) ? LiquidRadioTheme.accent : .secondary)
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(program.title) 시작 알림 \(reminders.followed.contains(program.followKey) ? "해제" : "설정")")
            }
        }
        .opacity(past ? 0.6 : 1)
        .listRowBackground(OnAirTokens.card)
        .listRowSeparator(.hidden)
    }
}

// MARK: - 마이

struct MyRadioScreen: View {
    @Bindable var library: StationLibrary
    var openPlayer: () -> Void
    @State private var recent = RecentListening.shared
    @State private var weather = RadioWeatherModel.shared
    var body: some View {
        List {
            if !recent.entries.isEmpty {
                Section("최근 들은 방송") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(Array(recent.entries.prefix(8)), id: \.station.catalogKey) { entry in
                                Button { RadioPlayer.shared.play(entry.station); openPlayer() } label: {
                                    VStack(spacing: 6) {
                                        LiquidStationMark(station: entry.station, size: 58)
                                        Text(entry.station.name).font(.caption2).lineLimit(1)
                                    }.frame(width: 70)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                .listRowBackground(OnAirTokens.card)
            }
            Section("라디오와 하루") {
                NavigationLink { WakeRadioEditor(library: library) } label: { row("기상 라디오", "좋아하는 방송으로 아침 시작", "alarm") }
                NavigationLink { RoutineList(library: library) } label: { row("출근 · 퇴근 · 취침", "시간대별 방송과 자동 종료", "clock") }
                NavigationLink { FollowedPrograms() } label: { row("방송 알림", "\(ProgramReminders.shared.followed.count)개 프로그램", "bell") }
                NavigationLink { FavoriteOrderEditor(library: library) } label: { row("즐겨찾기 순서", "\(library.favorites.count)개 채널", "star") }
            }
            .listRowBackground(OnAirTokens.card)
            Section("더 보기") {
                NavigationLink { HapticGlassTuner(library: library, player: RadioPlayer.shared).padding().navigationTitle("주파수 튜너") } label: { row("주파수 튜너", "다이얼로 채널 돌리기", "dial.low") }
                NavigationLink { WeatherDetailView() } label: { row("날씨", weather.weather.map { "\(weather.region.name) \($0.temperatureLabel) · \($0.condition)" } ?? weather.region.name, "cloud.sun") }
            }
            .listRowBackground(OnAirTokens.card)
            Section {
                NavigationLink { RadioPreferencesView() } label: { row("설정", "화면 · 지역 · 기록", "gearshape") }
            }
            .listRowBackground(OnAirTokens.card)
        }
        .scrollContentBackground(.hidden)
        .background { LiquidRadioBackground() }
        .navigationTitle("보관함")
    }
    private func row(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body.weight(.medium)).foregroundStyle(LiquidRadioTheme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }.padding(.vertical, 2)
    }
}

private struct RoutineList: View {
    @Bindable var library: StationLibrary
    @State private var presets = RadioPresets.shared
    var body: some View {
        List {
            Section {
                ForEach(RadioPresetKind.allCases) { kind in
                    NavigationLink { PresetEditor(kind: kind, library: library) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: kind.icon).foregroundStyle(LiquidRadioTheme.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title + " 라디오")
                                Text(presets.values.first { $0.kind == kind }?.station.name ?? "방송 선택").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } footer: { Text("위젯과 Siri에서도 이 루틴을 바로 재생할 수 있어요.") }
        }.navigationTitle("하루의 라디오")
    }
}

private struct FollowedPrograms: View {
    @State private var reminders = ProgramReminders.shared
    var body: some View {
        List {
            if reminders.followed.isEmpty {
                ContentUnavailableView("알림 받는 프로그램이 없어요", systemImage: "bell", description: Text("편성 탭에서 벨을 눌러 추가하세요."))
            }
            ForEach(Array(reminders.followed).sorted(), id: \.self) { key in
                Text(key.split(separator: "|").last.map(String.init) ?? key)
                    .swipeActions { Button("해제", role: .destructive) { Task { await reminders.remove(key) } } }
            }
        }.navigationTitle("방송 알림")
    }
}

private struct FavoriteOrderEditor: View {
    @Bindable var library: StationLibrary
    var body: some View {
        List {
            if library.favorites.isEmpty {
                ContentUnavailableView("즐겨찾기가 비어 있어요", systemImage: "star", description: Text("LIVE에서 채널 카드의 별을 눌러 추가하세요."))
            }
            ForEach(library.favorites) { station in
                HStack(spacing: 12) { LiquidStationMark(station: station, size: 36); Text(station.name) }
            }
            .onMove { from, to in
                library.favorites.move(fromOffsets: from, toOffset: to)
                FavoriteOrder.save(library.favorites); library.persist()
            }
            .onDelete { offsets in offsets.map { library.favorites[$0] }.forEach { library.toggle($0) } }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("즐겨찾기 순서")
    }
}

// MARK: - 게임

struct GamesTabScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("방송은 계속 흘러나오고, 두던 판은 자동으로 저장돼요.").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
                game("체스", "컴퓨터와 두거나 둘이서 한 판, 끝나면 수를 되짚어 봐요.", "crown.fill", Color(red: 0.42, green: 0.39, blue: 0.95)) { ChessView() }
                game("오목", "다섯 돌을 먼저 잇는 쪽이 이겨요. 컴퓨터와 겨뤄 보세요.", "circle.grid.3x3.fill", Color(red: 0.13, green: 0.66, blue: 0.62)) { GomokuView() }
                game("스도쿠", "난이도 세 가지, 막히면 메모와 힌트를 써요.", "square.grid.3x3.fill", Color(red: 0.93, green: 0.58, blue: 0.24)) { SudokuView() }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background { LiquidRadioBackground() }
        .navigationTitle("게임")
    }
    private func game<Destination: View>(_ title: String, _ detail: String, _ symbol: String, _ color: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(OnAirTokens.background)
                    .frame(width: 60, height: 60).background(color, in: .rect(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold()).foregroundStyle(.primary)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnAirTokens.card, in: .rect(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(OnAirTokens.border.opacity(0.6), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("game-open-\(title)")
    }
}
