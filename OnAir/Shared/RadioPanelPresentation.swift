#if os(iOS)
import SwiftUI
import WidgetKit
struct RadioPanelView: View {
    let entry: RadioEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("온에어").font(.headline); Spacer(); Text("FM / SEOUL").font(.caption.monospaced()) }
            Text(RadioFrequency.label(entry.station)).font(.system(size: 64, weight: .light, design: .rounded)).minimumScaleFactor(0.5)
            Rectangle().fill(RadioDesign.coral).frame(height: 2)
            Text(entry.station?.name ?? "나의 주파수").font(.title3.weight(.semibold))
            Button(intent: RadioPlaybackIntent(stationID: entry.station?.id ?? "", shouldPause: entry.active || entry.connecting)) {
                Label(entry.active || entry.connecting ? "일시정지" : "방송 듣기", systemImage: entry.active || entry.connecting ? "pause.fill" : "play.fill")
            }.buttonStyle(.bordered)

            Spacer(minLength: 0)
            Text("즐겨찾기").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(entry.snapshot.favorites.prefix(3))) { station in
                Button(intent: RadioPlaybackIntent(stationID: station.id, shouldPause: false)) { HStack { Text(station.name); Spacer(); Image(systemName: "play.fill") }.font(.subheadline).padding(.vertical, 6) }.buttonStyle(.plain)
            }
            Text("인터넷 스트리밍").font(.caption2).foregroundStyle(.secondary)
        }.containerBackground(RadioDesign.cream, for: .widget).widgetURL(URL(string: "onair://player"))
    }
}
#endif
