import SwiftUI

@main struct OnAirTV: App {
    @State private var library = StationLibrary()
    var body: some Scene { WindowGroup { TVHome(library: library).environment(\.locale, Locale(identifier: "ko_KR")) } }
}
struct TVHome: View {
    @Bindable var library: StationLibrary
    @State private var player = RadioPlayer.shared
    @State private var onlyFavorites = false
    @State private var category = "전체"
    @FocusState private var headerFocused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 44) {
                    HStack { Label("온에어", systemImage: "dot.radiowaves.left.and.right").font(.title.weight(.black)); Spacer(); Button(onlyFavorites ? "모든 방송국" : "즐겨찾기") { onlyFavorites.toggle() }.focused($headerFocused); Button("새로고침") { Task { await library.refresh() } } }
                    HStack(spacing: 70) {
                        StationArtwork(station: player.station ?? library.stations.first ?? .preview, large: true).frame(width: 390, height: 390)
                        VStack(alignment: .leading, spacing: 24) {
                            Text("집 안에 흐르는\n좋은 목소리.").font(.system(size: 58, weight: .bold))
                            Text(player.station?.name ?? "오늘의 라디오를 골라보세요").font(.title2)
                            if let station = player.station {
                                Text(station.subtitle).foregroundStyle(.secondary)
                                Button { player.toggle() } label: { Label(player.isPlaying || player.buffering ? "일시정지" : "재생", systemImage: player.isPlaying || player.buffering ? "pause.fill" : "play.fill") }.buttonStyle(.glassProminent).tint(RadioDesign.coral)
                                Button { library.toggle(station) } label: { Label("즐겨찾기 변경", systemImage: library.favorites.contains(where: { $0.id == station.id }) ? "heart.fill" : "heart") }
                                Menu("취침 타이머") { Button("30분") { player.setSleep(minutes: 30) }; Button("60분") { player.setSleep(minutes: 60) }; Button("해제") { player.setSleep(minutes: nil) } }
                                if player.buffering { ProgressView("방송 연결 중") }
                            }
                            if let error = player.error { Text(error).font(.callout).foregroundStyle(.red) }
                        }
                    }
                    Picker("방송 종류", selection: $category) {
                        ForEach(Station.categories, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    Text(onlyFavorites ? "내가 좋아하는 주파수" : "오늘의 방송국").font(.title2.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 36)], spacing: 40) {
                        ForEach((onlyFavorites ? library.favorites : category == "뉴스·시사" ? library.newsStations : library.stations).filter { category == "전체" || $0.category == category }) { station in
                            Button { player.play(station) } label: {
                                VStack(alignment: .leading, spacing: 14) { StationArtwork(station: station).frame(width: 235, height: 235); Text(station.name).font(.headline).lineLimit(1); Text(station.category).font(.caption).foregroundStyle(.secondary) }.padding(14)
                            }.buttonStyle(.card)
                        }
                    }
                    if onlyFavorites && library.favorites.isEmpty { Text("방송을 선택한 뒤 즐겨찾기에 추가하세요.").foregroundStyle(.secondary) }
                    if let message = library.message { Text(message).font(.caption) }
                }.padding(64)
            }.background(RadioDesign.cream).foregroundStyle(RadioDesign.ink)
        }.defaultFocus($headerFocused, true).task { DeviceSync.shared.start(); library.reloadFavorites(); await library.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .onAirFavoritesChanged)) { _ in library.reloadFavorites() }.preferredColorScheme(.light)
    }
}
