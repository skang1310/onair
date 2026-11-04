import SwiftUI
import AppIntents
import UserNotifications

@main struct OnAirApp: App {
    @AppStorage("appearance") private var appearance = "system"
    private var selectedScheme: ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    @State private var library = StationLibrary()
    @Environment(\.scenePhase) private var scenePhase
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-radio-games") {
            for key in ["saved.chess", "saved.gomoku", "saved.sudoku"] { UserDefaults.standard.removeObject(forKey: key) }
            UserDefaults.standard.set(false, forKey: "chess.computer")
            UserDefaults.standard.set(false, forKey: "gomoku.computer")
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-showWidgets") { RadioWidgetPreview() }
                else { RadioHome(library: library) }
                #else
                RadioHome(library: library)
                #endif
            }
                .task { RemovedRadioFeatureCleanup.run(); RadioShortcuts.updateAppShortcutParameters(); UNUserNotificationCenter.current().delegate = RadioNotificationDelegate.shared; DeviceSync.shared.start(); library.reloadFavorites() }
                .onReceive(NotificationCenter.default.publisher(for: .onAirFavoritesChanged)) { _ in library.reloadFavorites() }
                .onChange(of: scenePhase) { _, phase in
                    #if DEBUG
                    if phase == .background && ProcessInfo.processInfo.arguments.contains("-verifyBackgroundAudio") { RadioPlayer.shared.verifyBackgroundPlayback() }
                    #endif
                    if phase == .active {
                        Task { await ProgramSchedule.shared.refresh() }
                    }
                }
                #if DEBUG
                .overlay(alignment: .top) {
                    if ProcessInfo.processInfo.arguments.contains("-verifyBackgroundAudio") && RadioPlayer.shared.backgroundPlaybackVerified {
                        Text("백그라운드 오디오 진행 확인").accessibilityIdentifier("background-audio-verified")
                    }
                }
                #endif
                .preferredColorScheme(selectedScheme)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                #if DEBUG
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    if let index = args.firstIndex(of: "-favoriteStationID"), args.indices.contains(index + 1), let station = library.stations.first(where: { $0.id == args[index + 1] }) { DeviceSync.shared.change(station, selected: true) }
                    if let index = args.firstIndex(of: "-removeFavoriteID"), args.indices.contains(index + 1), let station = library.stations.first(where: { $0.id == args[index + 1] }) { DeviceSync.shared.change(station, selected: false) }
                    if let index = args.firstIndex(of: "-playStationID"), args.indices.contains(index + 1), let station = library.stations.first(where: { $0.id == args[index + 1] }) { RadioPlayer.shared.play(station)

                    }
                }
                #endif
                .onOpenURL { url in
                    guard url.scheme == "onair", url.host == "play" else { return }
                    Task {
                        await library.refresh()
                        let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value
                        if let station = library.stations.first(where: { $0.id == id }) ?? library.favorites.first(where: { $0.id == id }) ?? SharedStore.read().station ?? library.stations.first {
                            RadioPlayer.shared.play(station)
                        }
                    }
                }
        }
    }
}
