import SwiftUI
import AVKit
import MediaPlayer
import UniformTypeIdentifiers

struct RadioHome: View {
    @Bindable var library: StationLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = RadioPlayer.shared
    @State private var recent = RecentListening.shared
    @State private var presets = RadioPresets.shared
    @State private var selection = 0
    @State private var draggingFavorite: String?
    @State private var query = ""
    @State private var category = "전체"
    @State private var showPlayer = false
    @State private var showAirPlay = false
    @State private var showWeatherWidget = false
    @State private var showWeather = false
    @State private var showSettings = false
    @State private var showSchedule = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("라디오", systemImage: "radio.fill", value: 0) {
                NavigationStack {
                    RadioDashboard(library: library, openPlayer: { showPlayer = true }, openSettings: { showSettings = true }, explore: { value in category = value; selection = 1 }, openGames: { selection = 3 })
                }
            }
            Tab("탐색", systemImage: "safari", value: 1) {
                NavigationStack { RadioExploreScreen(library: library, query: $query, category: $category) }
            }
            Tab("플레이", systemImage: "square.grid.2x2", value: 3) {
                NavigationStack { RadioGamesScreen() }
            }
            Tab("보관함", systemImage: "heart", value: 2) {
                NavigationStack { RadioCollectionScreen(library: library, openSettings: { showSettings = true }) }
            }
        }
        .tint(LiquidRadioTheme.accent)
        .tabViewStyle(.tabBarOnly)
        .tabBarMinimizeBehavior(.never)
        .modifier(StudioPlayerAccessory(player: player, openPlayer: { showPlayer = true }))
        .fullScreenCover(isPresented: $showPlayer) {
            NowPlaying(library: library)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("onAirShowAirPlay"))) { _ in
            showSettings = false; showWeatherWidget = false; showWeather = false; showSchedule = false; showPlayer = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                showAirPlay = true
            }
        }
        .sheet(isPresented: $showAirPlay) {
            NavigationStack {
                VStack(spacing: 24) {
                    if let station = player.station {
                        StationArtwork(station: station).frame(width: 90, height: 90)
                        Text(station.name).font(.title3.bold())
                    }
                    Text("아래 AirPlay 버튼을 눌러 스피커나 Apple TV를 선택하세요.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    AirPlayPicker().frame(width: 64, height: 64).accessibilityLabel("AirPlay 출력 기기 선택")
                    Spacer()
                }
                .padding(24)
                .padding(.top, 24)
                .navigationTitle("AirPlay 출력")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { showAirPlay = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                RadioPreferencesView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { showSettings = false } } }
            }
        }
        #if DEBUG
        .sheet(isPresented: $showWeatherWidget) { WeatherWidgetPreview() }
        #endif
        .fullScreenCover(isPresented: $showWeather) { WeatherDetailView() }
        .sheet(isPresented: $showSchedule) {
            NavigationStack {
                ScheduleView(library: library, stationKey: nil)
                    .toolbar { Button("닫기") { showSchedule = false } }
            }
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-showPlayer") { showPlayer = true }
            if args.contains("-showNews") { category = "뉴스·시사"; selection = 1 }
            if args.contains("-showFavorites") { selection = 2 }
            if args.contains("-showStations") { selection = 1 }
            if args.contains("-showGames") { selection = 3 }
            if args.contains("-showLibrary") { selection = 2 }
            if args.contains("-showSchedule") { showSchedule = true }
            if args.contains("-showWeather") { showWeather = true }
            if args.contains("-showWeatherWidget") { showWeatherWidget = true }
        }
        #endif
        .onOpenURL { url in
            if url.host == "player" || url.host == "play" { showPlayer = true }
            else if url.host == "weather" { showWeather = true }
            else if url.host == "stations" { selection = 1 }
            else if url.host == "news" { category = "뉴스·시사"; selection = 1 }
            else if url.host == "favorites" { selection = 2 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await RadioWeatherModel.shared.refresh(); await ProgramSchedule.shared.refresh() } }
        }
        .task { await RadioWeatherModel.shared.refresh() }
        .task { RadioPresets.shared.populate(from: library.stations); await library.refresh(); await ProgramSchedule.shared.refresh() }
        .alert("방송 연결 안내", isPresented: Binding(get: { player.error != nil }, set: { if !$0 { player.error = nil } })) {
            Button("확인") { player.error = nil }
        } message: { Text(player.error ?? "") }
    }

    private var filtered: [Station] {
        library.stations.filter {
            (category == "전체" || $0.category == category) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || RadioFrequency.label($0).contains(query))
        }
    }

    private func openStation(_ station: Station) {
        if player.station?.id != station.id || (!player.isPlaying && !player.buffering) {
            player.play(station)
        }
        showPlayer = true
    }

    private func card(_ station: Station) -> some View {
        LiquidStationCard(
            station: station,
            favorite: library.favorites.contains { $0.catalogKey == station.catalogKey },
            playing: player.station?.catalogKey == station.catalogKey && (player.isPlaying || player.buffering),
            play: { openStation(station) },
            toggleFavorite: { library.toggle(station) }
        )
        .contextMenu {
            Button("방송 연결 확인", systemImage: "antenna.radiowaves.left.and.right") {
                Task { await ConnectionHealth.shared.check(station, force: true) }
            }
        }
    }

    private func favoriteCard(_ station: Station) -> some View {
        card(station)
            .onDrag {
                draggingFavorite = station.catalogKey
                return NSItemProvider(object: station.catalogKey as NSString)
            }
            .onDrop(of: [UTType.text], delegate: FavoriteReorderDrop(target: station.catalogKey, dragging: $draggingFavorite, library: library))
            .accessibilityAction(named: "위로 이동") { library.shiftFavorite(station.catalogKey, offset: -1) }
            .accessibilityAction(named: "아래로 이동") { library.shiftFavorite(station.catalogKey, offset: 1) }
    }

    private var routineCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(presets.values) { preset in
                    Button {
                        presets.play(preset)
                        showPlayer = true
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: preset.kind.icon).font(.title2).foregroundStyle(LiquidRadioTheme.accent)
                            Text(preset.kind.title).font(.headline)
                            Text(preset.station.name).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .frame(width: 140, alignment: .leading)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.kind.title) · \(preset.station.name) 재생")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func libraryLink(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(LiquidRadioTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 16)
    }
}

// MARK: - Now Playing Compact Glass Card (홈 화면용 리퀴드 글래스 플로팅 카드)
struct NowPlayingCompactCard: View {
    let station: Station
    @Bindable var player: RadioPlayer
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    let openPlayer: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // 방송국 로고 마크
                Button(action: openPlayer) {
                    LiquidStationMark(station: station, size: 54)
                }
                .buttonStyle(.plain)

                // 곡명 & 프로그램 정보
                Button(action: openPlayer) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(station.name)
                                .font(.headline)
                                .lineLimit(1)
                            if let freq = RadioFrequency.values[station.catalogKey] {
                                Text(String(format: "%.1f", freq))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LiquidRadioTheme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LiquidRadioTheme.accent.opacity(0.12), in: Capsule())
                            }
                        }
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            let program = ProgramSchedule.shared.current(for: station, at: context.date)
                            Text(program?.title ?? station.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                // 즐겨찾기 하트 버튼
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(isFavorite ? LiquidRadioTheme.accent : .secondary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }

            // 하단 컨트롤: 연결 상태 & 큰 재생 버튼
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(player.isPlaying ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(player.connectionLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    player.toggle()
                } label: {
                    HStack(spacing: 8) {
                        if player.buffering {
                            ProgressView().tint(.white).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(player.isPlaying ? "일시정지" : "재생하기")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LiquidRadioTheme.accent, in: Capsule())
                    .shadow(color: LiquidRadioTheme.accent.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 15, y: 6)
    }
}

// MARK: - Quick Favorite Chip (가로형 글래스 칩)
struct QuickFavoriteChip: View {
    let station: Station
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LiquidStationMark(station: station, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(station.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if let freq = RadioFrequency.values[station.catalogKey] {
                        Text(String(format: "%.1f", freq))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(LiquidRadioTheme.accent)
                    }
                }
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidRadioTheme.accent)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(
                isPlaying ? LiquidRadioTheme.accent.opacity(0.12) : Color.primary.opacity(0.04),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        isPlaying ? LiquidRadioTheme.accent.opacity(0.5) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct RadioPreferencesView: View {
    @AppStorage("appearance") private var appearance = "system"
    @State private var recent = RecentListening.shared
    var body: some View {
        Form {
            Section("화면") { Picker("화면 모드", selection: $appearance) { Text("시스템 설정").tag("system"); Text("라이트 모드").tag("light"); Text("다크 모드").tag("dark") }.accessibilityIdentifier("appearance-picker") }
            Section("날씨") { NavigationLink("날씨와 지역", destination: WeatherSettingsView()) }
            Section("시스템과 기기") {
                Label(DeviceSync.shared.message, systemImage: "icloud")
                Text("제어센터에서 ‘내 라디오’를 추가하면 최근 방송을 바로 들을 수 있어요.").font(.footnote).foregroundStyle(.secondary)
                Text("홈 화면을 길게 눌러 온에어 위젯을 추가하세요. 스탠바이는 충전 중 아이폰을 가로로 놓고 위젯을 선택하세요.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("방송 알림") {
                ForEach(Array(ProgramReminders.shared.followed).sorted(), id: \.self) { key in HStack { Text(key.split(separator: "|").last.map(String.init) ?? key); Spacer(); Button("알림 해제") { Task { await ProgramReminders.shared.remove(key) } } } }
                if ProgramReminders.shared.followed.isEmpty { Text("편성표에서 좋아하는 프로그램의 알림을 설정하세요.").font(.footnote).foregroundStyle(.secondary) }
            }
            Section("청취 기록") { Button("최근 방송 기록 지우기", role: .destructive) { recent.clear() }.disabled(recent.entries.isEmpty) }
        }.navigationTitle("설정").navigationBarTitleDisplayMode(.inline)
    }
}

struct MiniRadioPlayer: View {
    let station: Station
    @Bindable var player: RadioPlayer
    let openPlayer: () -> Void
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openPlayer) {
                HStack(spacing: 10) {
                    if placement != .inline {
                        LiquidStationMark(station: station, size: 40)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(station.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        if placement != .inline {
                            Text(player.connectionLabel)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(station.name) 재생 화면 열기")
            Button { player.toggle() } label: {
                ZStack {
                    if player.buffering { ProgressView().tint(LiquidRadioTheme.accent) }
                    else { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3) }
                }.frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel(player.buffering ? "방송 연결 취소" : player.isPlaying ? "일시정지" : "재생")
        }
        .padding(.horizontal, placement == .inline ? 8 : 16)
        .padding(.vertical, placement == .inline ? 2 : 8)
        .accessibilityIdentifier("mini-radio-player")
    }
}

struct NowPlaying: View {
    @AppStorage("appearance") private var appearance = "system"
    @State private var showSchedule = false
    @State private var showStations = false
    @Bindable var library: StationLibrary
    @State private var player = RadioPlayer.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 상단 바: 닫기 버튼, ON AIR 네온 라이브 뱃지, 더보기 메뉴
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("재생 화면 닫기")

                        Spacer()

                        // 1번 아이콘 스타일 ON AIR 라이브 뱃지
                        HStack(spacing: 6) {
                            Circle()
                                .fill(player.isPlaying ? Color.red : Color.gray.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .shadow(color: player.isPlaying ? Color.red.opacity(0.9) : .clear, radius: 4)
                            Text("ON AIR")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(player.isPlaying ? Color.red : Color.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(player.isPlaying ? Color.red.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1))

                        Spacer()

                        Menu {
                            Button("오늘의 편성표", systemImage: "calendar") { showSchedule = true }
                            if let station = player.station {
                                Button("방송 연결 확인", systemImage: "antenna.radiowaves.left.and.right") {
                                    Task { await ConnectionHealth.shared.check(station, force: true) }
                                }
                                if let homepage = station.homepageURL { Link("방송사 공식 사이트", destination: homepage) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("플레이어 더 보기")
                    }

                    if let station = player.station {
                        Spacer(minLength: 20)

                        // 3D 리퀴드 글래스 아트워크
                        LiquidPlayerArtwork(station: station)
                            .frame(width: min(geometry.size.width * 0.67, geometry.size.height * 0.34, 290))
                            .shadow(color: .black.opacity(0.12), radius: 20, y: 12)
                            .gesture(DragGesture().onEnded { value in if value.translation.height > 80 { dismiss() } })

                        Spacer(minLength: 22)

                        // 방송국 및 프로그램명
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            let program = ProgramSchedule.shared.current(for: station, at: context.date)
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(station.name).font(.subheadline).foregroundStyle(.secondary)
                                    if let freq = RadioFrequency.values[station.catalogKey] {
                                        Text("FM " + String(format: "%.1f", freq))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(LiquidRadioTheme.accent)
                                    }
                                }
                                Text(program?.title ?? "실시간 라디오")
                                    .font(.system(size: 22, weight: .semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        RadioProgramSummary(station: station, compact: true)
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)

                        // 라이브 상태 인디케이터
                        HStack(spacing: 8) {
                            Circle().fill(LiquidRadioTheme.accent).frame(width: 5, height: 5)
                            Text(player.connectionLabel).font(.caption2).foregroundStyle(.secondary)
                            Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
                            Text(player.isPlaying ? "LIVE" : "RADIO")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(LiquidRadioTheme.accent)
                        }
                        .padding(.top, 20)

                        Spacer(minLength: 16)

                        // 재생/일시정지 및 이전/다음 스텝 컨트롤
                        HStack(spacing: 35) {
                            Button { step(-1) } label: {
                                Image(systemName: "backward.end").font(.system(size: 23)).frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("이전 방송국")

                            Button { player.toggle() } label: {
                                Group {
                                    if player.buffering {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 25, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(width: 64, height: 64)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(LiquidRadioTheme.accent)
                            .buttonBorderShape(.circle)
                            .shadow(color: LiquidRadioTheme.accent.opacity(0.4), radius: 10, y: 4)
                            .accessibilityLabel(player.isPlaying || player.buffering ? "일시정지" : "재생")

                            Button { step(1) } label: {
                                Image(systemName: "forward.end").font(.system(size: 23)).frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("다음 방송국")
                        }
                        .padding(.vertical, 10)

                        Spacer(minLength: 16)

                        // 볼륨 슬라이더
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill").font(.caption)
                            Group {
                                #if targetEnvironment(simulator)
                                Slider(value: Binding(get: { Double(player.volume) }, set: { player.volume = Float($0) }), in: 0...1).tint(LiquidRadioTheme.accent)
                                #else
                                SystemVolumeSlider()
                                #endif
                            }
                            .frame(height: 30)
                            .accessibilityLabel("볼륨")
                            Image(systemName: "speaker.wave.3").font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)

                        // 하단 툴바: 즐겨찾기, 타이머, AirPlay, 편성표, 채널목록
                        HStack {
                            Button {
                                library.toggle(station)
                            } label: {
                                Image(systemName: library.favorites.contains { $0.catalogKey == station.catalogKey } ? "heart.fill" : "heart")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("즐겨찾기 변경")

                            Spacer()

                            Menu {
                                ForEach([15, 30, 45, 60], id: \.self) { value in
                                    Button("\(value)분 후 끄기") { player.setSleep(minutes: value) }
                                }
                                Button("타이머 해제") { player.setSleep(minutes: nil) }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: player.sleepEnd == nil ? "moon" : "moon.fill")
                                    if let end = player.sleepEnd {
                                        Text(end, style: .timer).font(.caption.monospacedDigit())
                                    }
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("취침 타이머")

                            Spacer()

                            AirPlayPicker().frame(width: 44, height: 44).accessibilityLabel("AirPlay 오디오 출력")

                            Spacer()

                            Button { showSchedule = true } label: {
                                Image(systemName: "calendar").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("오늘의 편성표")

                            Spacer()

                            Button { showStations = true } label: {
                                Image(systemName: "list.bullet").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("방송국 목록")
                        }
                        .font(.system(size: 18))
                        .buttonStyle(.plain)
                        .padding(.top, 10)

                        if let error = player.error {
                            HStack {
                                Text(error).font(.caption).foregroundStyle(.secondary)
                                Button("다시 시도") { player.resume() }.font(.caption.weight(.semibold))
                            }
                            .padding(.top, 8)
                        }
                    } else {
                        ContentUnavailableView("방송을 선택해 주세요", systemImage: "radio")
                    }
                }
                .padding(.horizontal, geometry.size.width > 600 ? 80 : 26)
                .padding(.bottom, 24)
                .frame(maxWidth: 600)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.primary)
        .background { LiquidRadioBackground() }
        .tint(LiquidRadioTheme.accent)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .sheet(isPresented: $showSchedule) {
            NavigationStack {
                ScheduleView(library: library, stationKey: player.station?.catalogKey)
                    .toolbar { Button("닫기") { showSchedule = false } }
            }
        }
        .sheet(isPresented: $showStations) {
            NavigationStack {
                List(library.stations) { station in
                    Button {
                        player.play(station)
                        showStations = false
                    } label: {
                        HStack(spacing: 12) {
                            LiquidStationMark(station: station, size: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.name).foregroundStyle(.primary)
                                Text(station.category).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if station.catalogKey == player.station?.catalogKey {
                                Image(systemName: "waveform").foregroundStyle(LiquidRadioTheme.accent)
                            }
                        }
                    }
                }
                .navigationTitle("방송국 목록")
                .toolbar { Button("닫기") { showStations = false } }
            }
        }
    }

    func step(_ offset: Int) {
        guard !library.stations.isEmpty else { return }
        let index = library.stations.firstIndex(where: { $0.id == player.station?.id }) ?? 0
        player.play(library.stations[(index + offset + library.stations.count) % library.stations.count])
    }
}

private struct PlayerControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(minWidth: 44, minHeight: 44)
            .glassEffect(.regular.interactive(), in: .circle)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(); view.tintColor = .systemOrange
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct AirPlayPicker: UIViewRepresentable {
    var light = false
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(); view.prioritizesVideoDevices = false
        view.tintColor = light ? UIColor.white.withAlphaComponent(0.6) : .label
        view.activeTintColor = light ? .white : .systemOrange
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = light ? UIColor.white.withAlphaComponent(0.6) : .label
    }
}

private struct StudioPlayerAccessory: ViewModifier {
    @Bindable var player: RadioPlayer
    let openPlayer: () -> Void
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: player.station != nil) {
                if let station = player.station { MiniRadioPlayer(station: station, player: player, openPlayer: openPlayer) }
            }
        } else {
            content.tabViewBottomAccessory {
                if let station = player.station { MiniRadioPlayer(station: station, player: player, openPlayer: openPlayer) }
            }
        }
    }
}
