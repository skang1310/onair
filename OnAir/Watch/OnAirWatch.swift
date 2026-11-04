import SwiftUI
import WatchKit

@main struct OnAirWatch: App {
    @State private var library = StationLibrary()
    var body: some Scene { WindowGroup { WatchHome(library: library).environment(\.locale, Locale(identifier: "ko_KR")) } }
}
struct WatchHome: View {
    @Bindable var library: StationLibrary
    @State private var player = RadioPlayer.shared
    @State private var showTimer = false
    @State private var category = "전체"
    @State private var controlPhone = false
    @State private var sync = DeviceSync.shared
    @State private var page = 1
    @State private var favoritesOnly = false
    @State private var showReorder = false
    @State private var showAudioOutput = false
    @State private var handoffStationKey: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var crownFocused: Bool
    @State private var crownPosition = 0.0
    @State private var crownEventCount = 0
    @State private var crownVolume = Double(RadioPlayer.shared.volume)
    @State private var volumeVisible = false
    @State private var hideVolumeTask: Task<Void, Never>?
    private var crownActive: Bool { page == 1 && !showTimer && !showReorder && !showAudioOutput && scenePhase == .active }
    private var currentStation: Station? {
        controlPhone ? sync.remotePlayback?.station : player.station
    }
    private var displayedStation: Station? { currentStation ?? library.stations.first(where: { $0.name == "KBS Cool FM" }) ?? library.stations.first }
    private var playing: Bool { controlPhone ? sync.remotePlayback?.isPlaying == true : player.isPlaying }
    private var buffering: Bool { controlPhone ? sync.remotePlayback?.buffering == true : player.buffering }
    private var currentOutput: RadioAudioOutput {
        if controlPhone {
            guard sync.phoneReachable else { return .init(name: "iPhone 연결 끊김", symbol: "iphone.slash") }
            return sync.remotePlayback?.audioOutput ?? .init(name: "iPhone · 출력 확인 중", symbol: "iphone")
        }
        return player.audioOutput
    }
    private var channels: [Station] {
        let source = favoritesOnly ? library.favorites : category == "뉴스·시사" ? library.newsStations : library.stations
        return source.filter { category == "전체" || $0.category == category }
    }
    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                channelPage.tag(0)
                playbackPage.tag(1)
                settingsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle(page == 0 ? "채널" : page == 2 ? "설정" : "")
            .background(LinearGradient(colors: [RadioDesign.coral.opacity(0.14), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        }.task { DeviceSync.shared.start(); library.reloadFavorites(); await library.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .onAirFavoritesChanged)) { _ in library.reloadFavorites() }
        .sheet(isPresented: $showTimer) {
            VStack {
                Text("취침 타이머").font(.headline)
                Button("15분 후 끄기") { if controlPhone { sync.sendCommand("sleep", minutes: 15) } else { player.setSleep(minutes: 15) }; showTimer = false }
                Button("30분 후 끄기") { if controlPhone { sync.sendCommand("sleep", minutes: 30) } else { player.setSleep(minutes: 30) }; showTimer = false }
                Button("타이머 해제") { if controlPhone { sync.sendCommand("sleep", minutes: 0) } else { player.setSleep(minutes: nil) }; showTimer = false }
            }
        }
        .sheet(isPresented: $showReorder) {
            if #available(watchOS 27.0, *) { WatchFavoriteReorder(library: library) }
        }
        .sheet(isPresented: $showAudioOutput) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "airplay.audio").font(.title2).foregroundStyle(RadioDesign.coral)
                        Label(currentOutput.name, systemImage: currentOutput.symbol).font(.caption.weight(.semibold))
                        NavigationLink("Watch에서 출력 선택") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("워치에서 바로 선택").font(.headline)
                                    Text("1. 측면 버튼을 눌러 제어 센터를 여세요.\n2. 오디오 출력 아이콘을 누르세요.\n3. 시스템에 표시되는 기기를 선택하세요.").font(.caption)
                                    Text("AirPods·Bluetooth 스피커는 워치에 직접 연결할 수 있습니다. HomePod·Apple TV 송출은 iPhone AirPlay 경로도 이용할 수 있어요.").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Text("iPhone에서 송출하려면 아래 버튼을 누르세요.").font(.caption2).foregroundStyle(.secondary)
                        Button("iPhone에서 AirPlay 선택") {
                            guard sync.phoneReachable && !sync.remoteBusy else { return }
                            let station = displayedStation
                            handoffStationKey = station?.catalogKey
                            sync.sendCommand("airplay", station: station)
                        }.disabled(!sync.phoneReachable || sync.remoteBusy)
                        if !sync.phoneReachable { Text("iPhone에서 온에어를 열어 주세요.").font(.caption2).foregroundStyle(.secondary) }
                        if sync.remoteBusy { ProgressView() }
                        if let message = sync.remoteMessage { Text(message).font(.caption2).foregroundStyle(.orange) }
                        NavigationLink("시스템 재생 제어") { NowPlayingView() }
                    }
                }.navigationTitle("오디오 출력")
            }
        }
        .onChange(of: sync.remotePlayback?.updatedAt) { _, _ in
            if sync.remotePlayback?.isPlaying == true, let handoffStationKey, sync.remotePlayback?.station?.catalogKey == handoffStationKey {
                player.pause(); controlPhone = true; self.handoffStationKey = nil
            }
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-showPhone") { controlPhone = true }
            if args.contains("-showReorder") { showReorder = true }
            if args.contains("-showAudioOutput") { showAudioOutput = true }
            if args.contains("-previewVolumeHUD") { crownVolume = 0.65; volumeVisible = true }
            if let i = args.firstIndex(of: "-watchPage"), args.indices.contains(i + 1), let value = Int(args[i + 1]), (0...2).contains(value) { page = value }
        }
        .task {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-remotePause") || args.contains("-remotePlayCBS") {
                for _ in 0..<100 { if sync.phoneReachable && !sync.remoteBusy { break }; try? await Task.sleep(for: .milliseconds(300)) }
                if args.contains("-remotePause") { sync.sendCommand("pause") }
                else { sync.sendCommand("play", station: Station.curated[0]) }
            }
        }
        #endif
        .onOpenURL { url in
            #if DEBUG
            if url.host == "remote" {
                let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "action" })?.value ?? "status"
                sync.sendCommand(action, station: action == "play" ? Station.curated[0] : nil); return
            }
            #endif
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value
            if let station = library.stations.first(where: { $0.id == id }) ?? SharedStore.read().station { player.play(station) }
        }
    }
    private var playbackPage: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 220
            VStack(spacing: compact ? 5 : 8) {
                Spacer(minLength: 0)
                if let station = displayedStation {
                    HStack(spacing: 10) {
                        StationArtwork(station: station, cornerRadius: 12)
                            .frame(width: compact ? 38 : 46, height: compact ? 38 : 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(station.name).font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                                .lineLimit(2).minimumScaleFactor(0.8)
                            HStack(spacing: 4) {
                                Circle().fill(playing ? RadioDesign.coral : .gray).frame(width: 4, height: 4)
                                Text(buffering ? "연결 중…" : playing ? "지금 듣는 중" : "재생 준비").font(.system(size: 10))
                            }.foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        Button { step(-1) } label: {
                            Image(systemName: "backward.end.fill").font(.system(size: 18)).frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("이전 채널")
                        Button { togglePlayback(station) } label: {
                            Image(systemName: playing || buffering ? "pause.fill" : "play.fill")
                                .font(.system(size: 23, weight: .semibold))
                                .frame(width: compact ? 48 : 56, height: compact ? 48 : 56)
                                .background(RadioDesign.coral.gradient, in: .circle)
                        }.buttonStyle(.plain).accessibilityLabel(playing || buffering ? "일시정지" : "재생")
                        .handGestureShortcut(.primaryAction, isEnabled: crownActive)
                        Button { step(1) } label: {
                            Image(systemName: "forward.end.fill").font(.system(size: 18)).frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("다음 채널")
                    }.disabled(controlPhone && sync.remoteBusy)
                }
                Spacer(minLength: 0)
                Button { showAudioOutput = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: currentOutput.symbol)
                        Text(currentOutput.name).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                    }.font(.system(size: 11)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.plain).accessibilityLabel("현재 출력: \(currentOutput.name). 오디오 출력 선택")
                if let end = controlPhone ? sync.remotePlayback?.sleepEnd : player.sleepEnd, end > .now {
                    HStack(spacing: 4) { Image(systemName: "moon.zzz"); Text(timerInterval: Date.now...end, countsDown: true) }
                        .font(.system(size: 10).monospacedDigit()).foregroundStyle(RadioDesign.coral)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 24)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .focusable(crownActive)
        .focused($crownFocused)
        .focusEffectDisabled()
        .scrollIndicators(.hidden)
        .digitalCrownRotation(Binding(get: { crownPosition }, set: { acceptCrownPosition($0) }), onIdle: { scheduleVolumeHide() })
        .digitalCrownAccessory(.hidden)
        .overlay(alignment: .trailing) {
            if volumeVisible && crownActive {
                WatchVolumeHUD(value: crownVolume)
                    .padding(.trailing, 5)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAction(named: "음량 높이기") { adjustVolume(0.05) }
        .accessibilityAction(named: "음량 낮추기") { adjustVolume(-0.05) }
        .task(id: crownActive) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            crownFocused = crownActive
            recordCrownState()
            guard crownActive else { return }
            #if DEBUG
            if crownActive && ProcessInfo.processInfo.arguments.contains("-verifyVolumeHUD") {
                let expected = max(0, crownVolume - 0.35)
                acceptCrownPosition(crownPosition - 7)
                await Task.yield()
                let changed = crownFocused && abs(Double(player.volume) - expected) < 0.01 && volumeVisible
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                print(changed && !volumeVisible ? "CROWN_HUD_FLOW_PASS" : "CROWN_HUD_FLOW_FAIL")
            }
            #endif
        }
        .onAppear { if controlPhone { sync.sendCommand("status") } }
        .onDisappear { hideVolumeTask?.cancel(); volumeVisible = false; crownFocused = false }
        .onChange(of: crownFocused) { _, _ in recordCrownState() }
        .onChange(of: crownActive) { _, active in
            if !active { crownFocused = false }
            if !active { hideVolumeTask?.cancel(); volumeVisible = false }
        }
        .onChange(of: sync.remoteVolume) { _, value in
            if controlPhone && !volumeVisible, let value { crownVolume = Double(value) }
        }
        .onChange(of: controlPhone) { _, value in
            volumeVisible = false
            crownVolume = Double(value ? sync.remoteVolume ?? 1 : player.volume)
            if value { sync.sendCommand("status") }
        }
        .onChange(of: sync.phoneReachable) { _, value in if value && controlPhone { sync.sendCommand("status") } }
    }
    private var channelPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Button { favoritesOnly = false } label: { Text("전체").font(.caption2).frame(maxWidth: .infinity) }.buttonStyle(.plain).padding(.vertical, 8).background(favoritesOnly ? Color.white.opacity(0.08) : RadioDesign.coral.opacity(0.22), in: .capsule).foregroundStyle(favoritesOnly ? Color.secondary : RadioDesign.coral)
                    Button { favoritesOnly = true } label: { Image(systemName: "heart.fill").font(.caption2).frame(maxWidth: .infinity) }.buttonStyle(.plain).padding(.vertical, 8).background(favoritesOnly ? RadioDesign.coral.opacity(0.22) : Color.white.opacity(0.08), in: .capsule).foregroundStyle(favoritesOnly ? RadioDesign.coral : Color.secondary).accessibilityLabel("즐겨찾기")
                }
                if category != "전체" { Button("\(category) · 전체 보기") { category = "전체" }.font(.caption2) }
                if channels.isEmpty { Text("즐겨찾는 채널의 하트를 눌러 추가하세요.").font(.caption).foregroundStyle(.secondary) }
                ForEach(channels) { station in
                    HStack(spacing: 5) {
                        Button { select(station); withAnimation { page = 1 } } label: {
                            HStack(spacing: 7) {
                                StationArtwork(station: station, cornerRadius: 9).frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name).font(.caption.weight(.semibold)).lineLimit(2)
                                    Text(station.category).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }.buttonStyle(.plain)
                        Button { library.toggle(station) } label: {
                            Image(systemName: library.favorites.contains(where: { $0.id == station.id }) ? "heart.fill" : "heart").frame(width: 32, height: 40)
                        }.buttonStyle(.plain).tint(RadioDesign.coral).accessibilityLabel("\(station.name) 즐겨찾기 변경")
                    }.padding(7).background(.white.opacity(0.07), in: .rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(currentStation?.id == station.id ? RadioDesign.coral : .clear, lineWidth: 1))
                }
            }.padding(.bottom, 24)
        }
    }
    private var settingsPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                Picker("재생 기기", selection: $controlPhone) { Text("이 Watch").tag(false); Text("iPhone 제어").tag(true) }.pickerStyle(.navigationLink)
                if controlPhone { Text(sync.phoneReachable ? "iPhone 연결됨" : "iPhone 연결 대기").font(.caption2).foregroundStyle(.secondary) }
                Picker("방송 종류", selection: $category) { ForEach(Station.categories, id: \.self) { Text($0).tag($0) } }.pickerStyle(.navigationLink)
                Button("AirPlay·오디오 출력", systemImage: "airplay.audio") { showAudioOutput = true }
                Button("취침 타이머", systemImage: "moon.zzz") { showTimer = true }
                if #available(watchOS 27.0, *) {
                    Button("즐겨찾기 순서", systemImage: "arrow.up.arrow.down") { showReorder = true }
                }
                Button("목록 새로고침", systemImage: "arrow.clockwise") { Task { await library.refresh() } }
                if controlPhone { Button("iPhone 상태 확인") { sync.sendCommand("status") } }
                if let message = controlPhone ? sync.remoteMessage : player.error { Text(message).font(.caption2).foregroundStyle(.orange) }
                if let message = library.message { Text(message).font(.caption2).foregroundStyle(.secondary) }
            }.padding(.bottom, 24)
        }
    }
    private func acceptCrownPosition(_ value: Double) {
        guard value.isFinite else { return }
        let delta = value - crownPosition
        crownPosition = value
        guard crownActive, delta != 0 else { return }
        crownEventCount += 1
        adjustVolume(delta * 0.05)
        recordCrownState()
    }
    private func recordCrownState() {
        #if DEBUG
        let state: [String: Any] = ["input": "swiftui", "focused": crownFocused, "active": crownActive, "events": crownEventCount, "volume": crownVolume, "visible": volumeVisible, "timestamp": Date.now.timeIntervalSince1970]
        if let data = try? JSONSerialization.data(withJSONObject: state),
           let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: directory.appendingPathComponent("CrownState.json"), options: .atomic)
        }
        #endif
    }
    private func adjustVolume(_ offset: Double) {
        guard crownActive else { return }
        crownVolume = min(1, max(0, crownVolume + offset))
        updateVolume()
        scheduleVolumeHide()
    }
    private func updateVolume() {
        hideVolumeTask?.cancel()
        if controlPhone { sync.sendVolume(Float(crownVolume)) }
        else { player.volume = Float(crownVolume) }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { volumeVisible = true }
        scheduleVolumeHide()
    }
    private func scheduleVolumeHide() {
        hideVolumeTask?.cancel()
        hideVolumeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { volumeVisible = false }
        }
    }
    private func select(_ station: Station) {
        if controlPhone { sync.sendCommand("play", station: station) } else { player.play(station) }
    }
    private func togglePlayback(_ station: Station) {
        if controlPhone {
            if playing || buffering { sync.sendCommand("pause") }
            else if currentStation == nil { select(station) }
            else { sync.sendCommand("resume") }
        } else if player.station == nil { player.play(station) } else { player.toggle() }
    }
    private func step(_ offset: Int) {
        let source = library.favorites.isEmpty ? library.stations : library.favorites
        guard !source.isEmpty else { return }
        let index = source.firstIndex { $0.catalogKey == currentStation?.catalogKey } ?? 0
        select(source[(index + offset + source.count) % source.count])
    }

}

/// Temporary, non-interactive volume feedback beside the Digital Crown.
struct WatchVolumeHUD: View {
    var value: Double
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: value <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 9, weight: .semibold))
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(.white).frame(height: geometry.size.height * min(1, max(0, value)))
                }
            }.frame(width: 5, height: 48)
            Text("\(Int((min(1, max(0, value)) * 100).rounded()))%")
                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 9).frame(width: 30)
        .background(.black.opacity(0.8), in: .capsule)
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("음량")
        .accessibilityValue("\(Int((min(1, max(0, value)) * 100).rounded()))퍼센트")
    }
}

@available(watchOS 27.0, *)
struct WatchFavoriteReorder: View {
    @Bindable var library: StationLibrary
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("채널을 길게 눌러 원하는 위치로 옮기세요.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if library.favorites.isEmpty {
                        Text("채널 목록에서 하트를 눌러 즐겨찾기를 추가하세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(library.favorites) { station in
                        HStack(spacing: 8) {
                            StationArtwork(station: station, cornerRadius: 8).frame(width: 28, height: 28)
                            Text(station.name).font(.caption.weight(.semibold)).lineLimit(2)
                            Spacer(minLength: 0)
                            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                        }.padding(10).background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
                        .accessibilityAction(named: "위로 이동") { library.shiftFavorite(station.catalogKey, offset: -1) }
                        .accessibilityAction(named: "아래로 이동") { library.shiftFavorite(station.catalogKey, offset: 1) }
                    }.reorderable()
                }
                .reorderContainer(for: Station.self) { difference in
                    let before: String?
                    switch difference.destination.position {
                    case .before(let id): before = id
                    case .end: before = nil
                    }
                    library.moveFavorites(ids: difference.sources, before: before)
                }
            }.navigationTitle("순서 편집")
        }
    }
}

