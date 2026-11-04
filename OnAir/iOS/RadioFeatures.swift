import SwiftUI
import WidgetKit

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
