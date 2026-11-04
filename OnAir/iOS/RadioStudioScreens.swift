import SwiftUI
import UniformTypeIdentifiers

private enum StudioStyle {
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.17)
    static let orange = LiquidRadioTheme.accent
    static func section(_ title: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold()).tracking(-0.4)
            if let caption { Text(caption).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct RadioDashboard: View {
    @Bindable var library: StationLibrary
    var openPlayer: () -> Void
    var openSettings: () -> Void
    var explore: (String) -> Void
    var openGames: () -> Void
    @State private var player = RadioPlayer.shared
    @State private var recent = RecentListening.shared
    private var featured: Station? { player.station ?? recent.entries.first?.station ?? library.stations.first(where: { $0.catalogKey == "cbsmusic" }) ?? library.stations.first }
    private var shortcuts: [Station] { Array((library.favorites.isEmpty ? library.stations : library.favorites).prefix(8)) }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) { Circle().fill(StudioStyle.orange).frame(width: 5, height: 5); Text("YOUR DAILY FREQUENCY").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.5) }.foregroundStyle(.secondary)
                        Text("온에어").font(.system(size: 32, weight: .bold)).tracking(-1)
                    }
                    Spacer()
                    Button { explore("전체") } label: { Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("방송국 검색")
                    Button(action: openSettings) { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44).background(.primary.opacity(0.04), in: .circle) }.accessibilityLabel("설정")
                }.buttonStyle(.plain)
                if let station = featured { RadioFeaturedStation(station: station, openPlayer: openPlayer) }
                VStack(alignment: .leading, spacing: 15) {
                    HStack { StudioStyle.section(library.favorites.isEmpty ? "한 번에, 바로 듣기" : "나의 즐겨찾기"); Spacer(); Button("모두 보기") { explore("전체") }.font(.caption.weight(.semibold)) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(shortcuts) { station in
                                Button { play(station) } label: {
                                    VStack(spacing: 8) {
                                        LiquidStationMark(station: station, size: 62)
                                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(player.station?.catalogKey == station.catalogKey ? StudioStyle.orange : .clear, lineWidth: 2).padding(-3))
                                        Text(station.name).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center).frame(width: 74)
                                    }
                                }.buttonStyle(.plain).foregroundStyle(.primary).accessibilityLabel("\(station.name) 바로 듣기")
                            }
                        }.padding(4)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    StudioStyle.section("지금의 기분에 맞게")
                    HStack(spacing: 10) {
                        mood("음악에 집중", symbol: "music.note", category: "음악", color: .indigo)
                        mood("세상의 이야기", symbol: "newspaper", category: "뉴스·시사", color: .teal)
                        mood("차분한 휴식", symbol: "pianokeys", category: "클래식", color: .brown)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { StudioStyle.section("지금 만나는 채널", caption: "음악도, 이야기에도 귀 기울여요"); Spacer(); Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(StudioStyle.orange) }
                    VStack(spacing: 0) { ForEach(Array(library.stations.prefix(4))) { StudioStationRow(station: $0, library: library) } }
                }
                if !recent.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        StudioStyle.section("다시 이어 듣기")
                        ForEach(Array(recent.entries.prefix(3)), id: \.station.catalogKey) { StudioStationRow(station: $0.station, library: library) }
                    }
                }
                Button(action: openGames) {
                    HStack(spacing: 14) {
                        Image(systemName: "square.grid.3x3").font(.title2).foregroundStyle(StudioStyle.orange).frame(width: 48, height: 48).background(StudioStyle.orange.opacity(0.1), in: .rect(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 4) { Text("듣는 동안, 가볍게 한 판").font(.subheadline.bold()); Text("체스 · 오목 · 스도쿠").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "arrow.up.right").font(.caption.bold())
                    }.padding(16).background(.primary.opacity(0.035), in: .rect(cornerRadius: 22))
                }.buttonStyle(.plain).foregroundStyle(.primary)
                NavigationLink { WeatherDetailView() } label: { RadioWeatherCard() }.buttonStyle(.plain)
                HStack { Text(Date.now, format: .dateTime.month().day().weekday()).font(.caption2); Spacer(); Text("MAKE ROOM FOR RADIO").font(.system(size: 8, design: .monospaced)).tracking(1.5) }.foregroundStyle(.tertiary)
            }.padding(22).padding(.bottom, 20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background { LiquidRadioBackground() }.toolbar(.hidden, for: .navigationBar)
            .refreshable { await library.refresh(); await ProgramSchedule.shared.refresh(force: true) }
    }
    private func play(_ station: Station) { if player.station?.catalogKey != station.catalogKey || (!player.isPlaying && !player.buffering) { player.play(station) } }
    private func mood(_ title: String, symbol: String, category: String, color: Color) -> some View {
        Button { explore(category) } label: {
            VStack(alignment: .leading, spacing: 16) { Image(systemName: symbol).font(.system(size: 21, weight: .medium)); Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true) }
                .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(13).foregroundStyle(color).background(color.opacity(0.085), in: .rect(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
}

private struct RadioFeaturedStation: View {
    let station: Station
    let openPlayer: () -> Void
    @State private var player = RadioPlayer.shared
    private var active: Bool { player.station?.catalogKey == station.catalogKey && (player.isPlaying || player.buffering) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(active ? player.connectionLabel : "지금, 라디오를 켜세요", systemImage: active ? "waveform" : "dot.radiowaves.left.and.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("LIVE RADIO").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.5).padding(.horizontal, 9).padding(.vertical, 6).background(.white.opacity(0.1), in: .capsule)
            }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(station.name).font(.system(size: 25, weight: .bold)).tracking(-0.8).lineLimit(2)
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(ProgramSchedule.shared.current(for: station, at: context.date)?.title ?? station.subtitle).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                LiquidStationMark(station: station, size: 70).rotationEffect(.degrees(5))
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    let frequency = RadioFrequency.label(station)
                    Text(frequency == "LIVE" ? "ON AIR" : frequency).font(.system(size: 38, weight: .light, design: .rounded)).tracking(-1.5)
                    Button(action: openPlayer) { HStack(spacing: 5) { Text(active ? player.audioOutput.name : "실시간 스트리밍"); Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold)) }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)) }.buttonStyle(.plain).disabled(player.station == nil)
                }
                Spacer()
                Button {
                    if player.station?.catalogKey == station.catalogKey { player.toggle() } else { player.play(station) }
                } label: {
                    Group { if active && player.buffering { ProgressView().tint(.white) } else { Image(systemName: active ? "pause.fill" : "play.fill").font(.system(size: 23, weight: .semibold)) } }
                        .frame(width: 58, height: 58).foregroundStyle(.white).background(StudioStyle.orange.gradient, in: .circle)
                }.buttonStyle(.plain).accessibilityIdentifier("hero-play").accessibilityLabel(active ? "라디오 일시정지" : "라디오 재생")
            }
        }.padding(23).foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.25), StudioStyle.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct StudioStationRow: View {
    let station: Station
    @Bindable var library: StationLibrary
    @State private var player = RadioPlayer.shared
    var body: some View {
        LiquidStationCard(station: station,
                          favorite: library.favorites.contains { $0.catalogKey == station.catalogKey },
                          playing: player.station?.catalogKey == station.catalogKey && (player.isPlaying || player.buffering),
                          play: { if player.station?.catalogKey == station.catalogKey { player.toggle() } else { player.play(station) } },
                          toggleFavorite: { library.toggle(station) })
        .contextMenu {
            Button("방송 연결 확인", systemImage: "antenna.radiowaves.left.and.right") { Task { await ConnectionHealth.shared.check(station, force: true) } }
        }
    }
}

private struct StudioStationTile: View {
    let station: Station
    @Bindable var library: StationLibrary
    @State private var player = RadioPlayer.shared
    var body: some View {
        VStack(spacing: 0) {
            Button {
                if player.station?.catalogKey == station.catalogKey { player.toggle() } else { player.play(station) }
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { LiquidStationMark(station: station, size: 64); Spacer(minLength: 0) }
                    Text(station.name).font(.subheadline.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(station.name) 재생").accessibilityIdentifier("station-play-\(station.catalogKey)")
            HStack {
                Text(RadioFrequency.label(station)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button { library.toggle(station) } label: { Image(systemName: library.favorites.contains { $0.catalogKey == station.catalogKey } ? "heart.fill" : "heart").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(StudioStyle.orange).accessibilityLabel("\(station.name) 즐겨찾기 변경").accessibilityIdentifier("station-favorite-\(station.catalogKey)")
            }
        }.padding(16).background(.primary.opacity(0.035), in: .rect(cornerRadius: 22))
    }
}

struct RadioExploreScreen: View {
    @Bindable var library: StationLibrary
    @Binding var query: String
    @Binding var category: String
    @State private var layoutGrid = false
    private var filtered: [Station] { library.stations.filter { (category == "전체" || $0.category == category) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || RadioFrequency.label($0).contains(query)) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { StudioStyle.section("듣고 싶은 채널을 찾아요", caption: "방송국 이름이나 주파수로 검색하세요"); Spacer(); Button { layoutGrid.toggle() } label: { Image(systemName: layoutGrid ? "list.bullet" : "square.grid.2x2").frame(width: 44, height: 44) }.accessibilityLabel("목록 표시 방식 변경") }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(Station.categories, id: \.self) { item in
                        Button { category = item } label: { Text(item).font(.subheadline.weight(.semibold)).padding(.horizontal, 18).frame(minHeight: 44).foregroundStyle(category == item ? Color.white : .primary).background(category == item ? StudioStyle.orange : Color.primary.opacity(0.045), in: .capsule) }.buttonStyle(.plain).accessibilityAddTraits(category == item ? .isSelected : [])
                    } }
                }
                if category == "뉴스·시사" { NavigationLink { NewsBrowser(library: library) } label: { Label("지역별 뉴스·시사 탐색", systemImage: "newspaper").font(.subheadline.weight(.semibold)) } }
                HStack { Text(category == "전체" ? "모든 방송국" : category).font(.headline); Spacer(); Text("\(filtered.count)개 채널").font(.caption).foregroundStyle(.secondary) }
                if filtered.isEmpty { ContentUnavailableView.search(text: query) }
                if layoutGrid {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) { ForEach(filtered) { station in
                        StudioStationTile(station: station, library: library)
                    } }
                } else { LazyVStack(spacing: 0) { ForEach(filtered) { StudioStationRow(station: $0, library: library) } } }
            }.padding(22).padding(.bottom, 20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background { LiquidRadioBackground() }.navigationTitle("탐색").navigationBarTitleDisplayMode(.large).toolbar(.visible, for: .navigationBar)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "방송국 또는 주파수")
            .refreshable { await library.refresh() }
    }
}

struct RadioCollectionScreen: View {
    @Bindable var library: StationLibrary
    var openSettings: () -> Void
    @State private var recent = RecentListening.shared
    @State private var presets = RadioPresets.shared
    @State private var dragging: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack { StudioStyle.section("나의 라디오", caption: "즐겨찾기 \(library.favorites.count)개 · 언제든 다시 듣기"); Spacer(); Image(systemName: "heart.fill").foregroundStyle(StudioStyle.orange) }
                if library.favorites.isEmpty { ContentUnavailableView("취향을 하나씩 담아보세요", systemImage: "heart", description: Text("방송국 옆 하트를 누르면 여기에 모여요.")) }
                else { VStack(spacing: 0) { ForEach(library.favorites) { station in
                    StudioStationRow(station: station, library: library)
                        .onDrag { dragging = station.catalogKey; return NSItemProvider(object: station.catalogKey as NSString) }
                        .onDrop(of: [UTType.text], delegate: FavoriteReorderDrop(target: station.catalogKey, dragging: $dragging, library: library))
                        .accessibilityAction(named: "위로 이동") { library.shiftFavorite(station.catalogKey, offset: -1) }
                        .accessibilityAction(named: "아래로 이동") { library.shiftFavorite(station.catalogKey, offset: 1) }
                } } }
                if library.favorites.count > 1 { Label("길게 눌러 원하는 순서로 정리하세요", systemImage: "hand.draw").font(.caption).foregroundStyle(.secondary) }
                StudioStyle.section("라디오와 함께하는 하루")
                VStack(spacing: 0) {
                    NavigationLink { WakeRadioEditor(library: library) } label: { utility("기상 라디오", subtitle: "좋아하는 방송으로 하루 시작", symbol: "sunrise") }
                    Divider()
                    NavigationLink { ScheduleView(library: library, stationKey: nil) } label: { utility("오늘의 편성표", subtitle: "프로그램과 시작 알림 확인", symbol: "calendar") }
                    Divider()
                    NavigationLink { HapticGlassTuner(library: library, player: RadioPlayer.shared).padding().navigationTitle("주파수 튜너") } label: { utility("주파수 튜너", subtitle: "다이얼을 움직이며 채널 탐색", symbol: "dial.low") }
                }.buttonStyle(.plain).padding(.horizontal, 15).background(.primary.opacity(0.03), in: .rect(cornerRadius: 22))
                StudioStyle.section("나만의 청취 루틴")
                VStack(spacing: 0) { ForEach(RadioPresetKind.allCases) { kind in
                    NavigationLink { PresetEditor(kind: kind, library: library) } label: { utility(kind.title + " 라디오", subtitle: "방송과 자동 종료 시간 설정", symbol: kind.icon) }
                } }.buttonStyle(.plain).padding(.horizontal, 15).background(.primary.opacity(0.03), in: .rect(cornerRadius: 22))
                if !recent.entries.isEmpty { StudioStyle.section("최근 들은 방송"); ForEach(Array(recent.entries.prefix(5)), id: \.station.catalogKey) { StudioStationRow(station: $0.station, library: library) } }
            }.padding(22).padding(.bottom, 20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background { LiquidRadioBackground() }.navigationTitle("보관함").navigationBarTitleDisplayMode(.large).toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: openSettings) { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("설정") } }
    }
    private func utility(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) { Image(systemName: symbol).font(.title3).foregroundStyle(StudioStyle.orange).frame(width: 30); VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }.padding(.vertical, 16)
    }
}

struct RadioGamesScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StudioStyle.section("귀는 라디오에, 손은 한 수에", caption: "듣던 방송은 그대로 · 게임은 자동 저장돼요")
                gameLink("체스", detail: "컴퓨터 대결 · 두 사람이 함께 · 대국 복기", icon: "crown", color: .indigo) { ChessView() }
                gameLink("오목", detail: "한 줄의 다섯 돌 · 컴퓨터 대결 · 복기", icon: "circle.grid.3x3", color: .teal) { GomokuView() }
                gameLink("스도쿠", detail: "세 가지 난이도 · 메모 · 힌트", icon: "square.grid.3x3", color: .brown) { SudokuView() }
            }.padding(22).padding(.bottom, 20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background { LiquidRadioBackground() }.navigationTitle("플레이").navigationBarTitleDisplayMode(.large).toolbar(.visible, for: .navigationBar)
    }
    private func gameLink<Content: View>(_ title: String, detail: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        NavigationLink(destination: content()) {
            HStack(spacing: 18) { Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundStyle(color).frame(width: 68, height: 78).background(color.opacity(0.08), in: .rect(cornerRadius: 20)); VStack(alignment: .leading, spacing: 7) { Text(title).font(.title3.bold()); Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }; Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }.padding(18).background(.primary.opacity(0.035), in: .rect(cornerRadius: 24))
        }.buttonStyle(.plain).foregroundStyle(.primary).accessibilityIdentifier("game-open-\(title)")
    }
}
