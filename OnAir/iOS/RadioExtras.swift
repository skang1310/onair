import SwiftUI
import AlarmKit

struct WakeRadioEditor: View {
    let library: StationLibrary
    @State private var time = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    @State private var stationID = Station.curated.first { $0.catalogKey == "cbsstandard" }?.id ?? ""
    @State private var weekdays = true
    @State private var saving = false
    @State private var message: String?
    var body: some View {
        Form {
            Section("기상 라디오") {
                DatePicker("기상 시간", selection: $time, displayedComponents: .hourAndMinute)
                Picker("방송", selection: $stationID) { ForEach(library.stations) { Text($0.name).tag($0.id) } }
                Toggle("평일마다", isOn: $weekdays)
                Text("알람을 끄면 방송을 연결합니다. 인터넷이 없어도 시스템 알람은 울립니다.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button(saving ? "저장 중…" : "기상 알람 저장") { save() }.disabled(saving)
                Button("기상 알람 삭제", role: .destructive) { do { try WakeRadio.cancel(); message = "알람을 삭제했어요" } catch { message = "알람 삭제를 다시 시도해 주세요" } }
                if let name = SharedStore.defaults.string(forKey: "wake-radio-station") { Text("설정한 방송 · \(name)").font(.caption) }
            }
        }.onAppear {
            if let value = SharedStore.defaults.object(forKey: "wake-radio-time") as? Date { time = value }
            if let value = SharedStore.defaults.string(forKey: "wake-radio-station-id"), library.stations.contains(where: { $0.id == value }) { stationID = value }
            if let value = SharedStore.defaults.object(forKey: "wake-radio-weekdays") as? Bool { weekdays = value }
        }.navigationTitle("기상 라디오").alert("기상 라디오", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("확인") { message = nil } } message: { Text(message ?? "") }
    }
    private func save() {
        guard let station = library.stations.first(where: { $0.id == stationID }) else { return }
        saving = true
        Task { defer { saving = false }; do { try await WakeRadio.schedule(time: time, station: station, weekdays: weekdays); message = "알람을 저장했어요" } catch { message = "설정에서 온에어 알람 권한을 확인해 주세요" } }
    }
}

struct BedsideRadioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player = RadioPlayer.shared
    @State private var brightness = 0.75
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 22) {
                HStack { Text("NIGHT RADIO").font(.system(size: 11, design: .monospaced)).tracking(2); Spacer(); Button("닫기") { dismiss() }.frame(minWidth: 44, minHeight: 44) }
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { context in Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)).font(.system(size: min(proxy.size.width * 0.23, proxy.size.height * 0.33), weight: .ultraLight, design: .rounded)).monospacedDigit() }
                HStack(spacing: 14) {
                    VStack(alignment: .leading) { Text(RadioFrequency.label(player.station) + " / " + (player.station?.name ?? "온에어")).font(.headline); if let end = player.sleepEnd { Text(end, style: .timer).font(.caption.monospacedDigit()) } }
                    Button { player.toggle() } label: { Image(systemName: player.isPlaying || player.buffering ? "pause.fill" : "play.fill").font(.title).frame(width: 64, height: 64) }.buttonStyle(.plain).accessibilityLabel("재생 또는 정지")
                }
                Spacer(minLength: 4)
                Slider(value: $brightness, in: 0.2...1).tint(.orange).accessibilityLabel("화면 표시 밝기")
            }.padding(28).opacity(brightness)
        }.foregroundStyle(.orange).background(.black).preferredColorScheme(.dark)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct RadioShareCard: View {
    let station: Station
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack { Text("ON AIR").tracking(3); Spacer(); Circle().fill(RadioDesign.coral).frame(width: 12, height: 12) }.font(.system(size: 13, weight: .bold, design: .monospaced))
            Spacer()
            Text(RadioFrequency.label(station)).font(.system(size: 92, weight: .light, design: .rounded))
            Rectangle().fill(RadioDesign.coral).frame(height: 3)
            Text(station.name).font(.title2.weight(.semibold))
            Text("오늘의 주파수.").foregroundStyle(.secondary)
            Spacer()
            Text("온에어 · 한국 라디오").font(.caption)
        }.padding(36).frame(width: 360, height: 480).foregroundStyle(.black).background(Color(red: 0.97, green: 0.96, blue: 0.93)).environment(\.colorScheme, .light)
    }
}
struct ShareRadioView: View {
    let station: Station
    @State private var poster: Image?
    var body: some View {
        ScrollView { VStack(spacing: 20) {
            RadioShareCard(station: station).scaleEffect(0.8).frame(width: 288, height: 384)
            if let poster { ShareLink(item: poster, preview: SharePreview("오늘의 주파수 · \(station.name)", image: poster)) { Label("주파수 카드 공유", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent) }
        }.padding(.vertical, 24).frame(maxWidth: .infinity) }.background(RadioDesign.cream).navigationTitle("오늘의 주파수").navigationBarTitleDisplayMode(.inline)
            .task { let renderer = ImageRenderer(content: RadioShareCard(station: station)); renderer.scale = 3; if let ui = renderer.uiImage { poster = Image(uiImage: ui) } }
    }
}
