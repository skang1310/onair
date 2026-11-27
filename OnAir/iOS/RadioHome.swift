import SwiftUI
import AVKit
import MediaPlayer
import UniformTypeIdentifiers

struct RadioHome: View {
    @Bindable var library: StationLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = RadioPlayer.shared
    @State private var selection = 0
    @State private var showPlayer = false
    @State private var showAirPlay = false
    @State private var showWeatherWidget = false
    @State private var showWeather = false
    @State private var showSettings = false
    @State private var showSchedule = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("라디오", systemImage: "radio", value: 0) {
                NavigationStack { LiveChannelsScreen(library: library, openPlayer: { showPlayer = true }) }
            }
            Tab("편성표", systemImage: "list.bullet.rectangle", value: 1) {
                NavigationStack { ScheduleTabScreen(library: library) }
            }
            Tab("게임", systemImage: "die.face.5", value: 3) {
                NavigationStack { GamesTabScreen() }
            }
            Tab("보관함", systemImage: "tray.full", value: 2) {
                NavigationStack { MyRadioScreen(library: library, openPlayer: { showPlayer = true }) }
            }
            Tab(value: 9, role: .search) {
                RadioSearchSheet(library: library, openPlayer: { showPlayer = true }, inTab: true)
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
            if args.contains("-showFavorites") || args.contains("-showLibrary") { selection = 2 }
            if args.contains("-showGames") { selection = 3 }
            if args.contains("-showStations") || args.contains("-showNews") { selection = 0 }
            if args.contains("-showSchedule") { selection = 1 }
            if args.contains("-showWeather") { showWeather = true }
            if args.contains("-showWeatherWidget") { showWeatherWidget = true }
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let value = Int(args[i + 1]) { selection = value }
        }
        #endif
        .onOpenURL { url in
            if url.host == "player" || url.host == "play" { showPlayer = true }
            else if url.host == "weather" { showWeather = true }
            else if url.host == "stations" || url.host == "news" || url.host == "favorites" { selection = 0 }
            else if url.host == "schedule" { selection = 1 }
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
}

struct RadioPreferencesView: View {
    @AppStorage("appearance") private var appearance = "dark"
    @State private var recent = RecentListening.shared
    var body: some View {
        Form {
            Section("화면") { Picker("화면 모드", selection: $appearance) { Text("다크 (추천)").tag("dark"); Text("라이트").tag("light"); Text("시스템 설정 따르기").tag("system") }.accessibilityIdentifier("appearance-picker") }
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
                    TimelineView(.periodic(from: .now, by: 20)) { context in
                        let line = player.isPlaying ? channelNowLine(station, at: context.date) : nil
                        VStack(alignment: .leading, spacing: 2) {
                            if placement != .inline {
                                HStack(spacing: 5) {
                                    if RadioFrequency.label(station) != "LIVE" {
                                        Text(RadioFrequency.label(station)).font(.system(.caption, design: .rounded).weight(.semibold)).monospacedDigit().foregroundStyle(LiquidRadioTheme.accent)
                                    }
                                    Text(station.name).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Text(placement == .inline ? (line ?? station.name) : (line ?? player.connectionLabel))
                                .font(.subheadline.weight(.semibold)).lineLimit(1)
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
    @AppStorage("appearance") private var appearance = "dark"
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
                                Text(program?.title ?? NowPlayingSongs.shared.board(for: station)?.program ?? "실시간 라디오")
                                    .font(.system(size: 22, weight: .semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        RadioProgramSummary(station: station, compact: true)
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)

                        NowPlayingSongRow(station: station)
                            .padding(.top, 10)

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
                                        ProgressView().tint(OnAirTokens.onAccent)
                                    } else {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 25, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(OnAirTokens.onAccent)
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
