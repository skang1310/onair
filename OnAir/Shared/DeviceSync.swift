import Foundation
import Observation
#if os(iOS) || os(watchOS)
@preconcurrency import WatchConnectivity
#endif

struct FavoriteChange: Codable, Sendable, Equatable {
    var station: Station
    var selected: Bool
    var changedAt: Date
    var revision: String
}
enum FavoriteMerge {
    static func merge(_ local: [String: FavoriteChange], _ remote: [String: FavoriteChange]) -> [String: FavoriteChange] {
        var result = local
        for (key, incoming) in remote {
            if let old = result[key], old.changedAt > incoming.changedAt || (old.changedAt == incoming.changedAt && old.revision >= incoming.revision) { continue }
            result[key] = incoming
        }
        return result
    }
    static func stations(_ ledger: [String: FavoriteChange]) -> [Station] {
        ledger.values.filter(\.selected).sorted { $0.changedAt < $1.changedAt }.map(\.station)
    }
}
extension Notification.Name { static let onAirFavoritesChanged = Notification.Name("onAirFavoritesChanged") }

@MainActor @Observable final class DeviceSync {
    static let shared = DeviceSync()
    var message = "즐겨찾기는 이 기기에 저장됩니다"
    var remotePlayback: ListeningSnapshot?
    var remoteVolume: Float?
    var remoteMessage: String?
    var remoteBusy = false
    var phoneReachable = false
    private var started = false
    private var cloudObserver: NSObjectProtocol?
    private var ledger: [String: FavoriteChange] = [:]
    private var commandTask: Task<Void, Never>?
    private var commandID = UUID()
    private var volumeTask: Task<Void, Never>?
    private var volumeRequest = UUID()
    #if os(iOS) || os(watchOS)
    private let watchDelegate = WatchBridgeDelegate()
    #endif
    private init() {}
    func start() {
        guard !started else { return }; started = true
        ledger = (UserDefaults.standard.data(forKey: "favorite-ledger").flatMap { try? JSONDecoder().decode([String: FavoriteChange].self, from: $0) }) ?? [:]
        if ledger.isEmpty {
            for station in SharedStore.read().favorites {
                ledger[station.catalogKey] = .init(station: station, selected: true, changedAt: .distantPast, revision: UUID().uuidString)
            }
        }
        #if CLOUD_SYNC && (os(iOS) || os(tvOS))
        cloudObserver = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeviceSync.shared.readCloud() }
        }
        NSUbiquitousKeyValueStore.default.synchronize(); readCloud()
        message = FileManager.default.ubiquityIdentityToken == nil ? "iCloud 로그인 후 기기 간 동기화됩니다" : "iCloud 즐겨찾기 동기화 사용 중"
        #else
        message = "iPhone–Watch 즐겨찾기 동기화"
        #endif
        #if os(iOS) || os(watchOS)
        if WCSession.isSupported() { WCSession.default.delegate = watchDelegate; WCSession.default.activate() }
        #endif
        persist(); publishFavorites()
    }
    func change(_ station: Station, selected: Bool) {
        start()
        ledger[station.catalogKey] = .init(station: station, selected: selected, changedAt: .now, revision: UUID().uuidString)
        persist(); publishFavorites()
    }
    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(ledger), forKey: "favorite-ledger")
        var snapshot = SharedStore.read(); snapshot.favorites = FavoriteOrder.sorted(FavoriteMerge.stations(ledger)); SharedStore.save(snapshot)
        NotificationCenter.default.post(name: .onAirFavoritesChanged, object: nil)
    }
    private func publishFavorites() {
        #if CLOUD_SYNC && (os(iOS) || os(tvOS))
        for (key, value) in ledger {
            NSUbiquitousKeyValueStore.default.set(try? JSONEncoder().encode(value), forKey: "favorite." + key)
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        #endif
        publishPlayback(SharedStore.read())
    }
    #if CLOUD_SYNC && (os(iOS) || os(tvOS))
    private func readCloud() {
        var remote: [String: FavoriteChange] = [:]
        for (key, value) in NSUbiquitousKeyValueStore.default.dictionaryRepresentation where key.hasPrefix("favorite.") {
            if let data = value as? Data, let item = try? JSONDecoder().decode(FavoriteChange.self, from: data) { remote[item.station.catalogKey] = item }
        }
        let merged = FavoriteMerge.merge(ledger, remote)
        guard merged != ledger else { return }; ledger = merged; persist(); publishFavorites()
    }
    #endif
    func receiveFavorites(_ data: Data) {
        guard let remote = try? JSONDecoder().decode([String: FavoriteChange].self, from: data) else { return }
        let merged = FavoriteMerge.merge(ledger, remote)
        guard merged != ledger else { return }; ledger = merged; persist(); publishFavorites()
    }
    func publishPlayback(_ snapshot: ListeningSnapshot) {
        #if os(iOS) || os(watchOS)
        guard started, WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        #endif
        var context: [String: Any] = [:]
        context["favorites"] = try? JSONEncoder().encode(ledger)
        #if os(iOS)
        context["playback"] = try? JSONEncoder().encode(snapshot)
        #endif
        try? WCSession.default.updateApplicationContext(context)
        #endif
    }
    func receivePlayback(_ data: Data) {
        if let snapshot = try? JSONDecoder().decode(ListeningSnapshot.self, from: data) {
            if let old = remotePlayback, old.updatedAt > snapshot.updatedAt { return }
            remotePlayback = snapshot
            #if DEBUG
            UserDefaults.standard.set(data, forKey: "debug-phone-playback")
            #endif
        }
    }
    func sendVolume(_ requested: Float) {
        #if os(watchOS)
        guard requested.isFinite else { return }
        let value = min(1, max(0, requested))
        volumeTask?.cancel()
        let request = UUID(); volumeRequest = request
        volumeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            guard WCSession.default.isReachable else {
                remoteMessage = "iPhone을 가까이 두고 온에어를 열어 주세요."; return
            }
            WCSession.default.sendMessage(["action": "volume", "volume": value], replyHandler: { reply in
                let confirmed = reply["volume"] as? Float
                Task { @MainActor in
                    guard DeviceSync.shared.volumeRequest == request else { return }
                    if let confirmed { DeviceSync.shared.remoteVolume = confirmed }
                }
            }, errorHandler: { _ in
                Task { @MainActor in
                    guard DeviceSync.shared.volumeRequest == request else { return }
                    DeviceSync.shared.remoteMessage = "음량을 전달하지 못했어요. iPhone 연결을 확인해 주세요."
                }
            })
        }
        #endif
    }
    func sendCommand(_ action: String, station: Station? = nil, minutes: Int? = nil) {
        #if os(watchOS)
        #if DEBUG
        UserDefaults.standard.set(["action": action, "busy": remoteBusy, "reachable": WCSession.default.isReachable, "time": Date.now.timeIntervalSince1970] as [String: Any], forKey: "debug-last-command")
        #endif
        guard !remoteBusy else { return }
        guard WCSession.default.isReachable else { remoteMessage = "iPhone을 가까이 두고 온에어를 열어 주세요."; phoneReachable = false; return }
        remoteBusy = true; remoteMessage = nil
        let requestID = UUID(); commandID = requestID
        var payload: [String: Any] = ["action": action]
        payload["station"] = station.flatMap { try? JSONEncoder().encode($0) }
        payload["minutes"] = minutes
        WCSession.default.sendMessage(payload, replyHandler: { reply in
            let data = reply["playback"] as? Data
            let volume = reply["volume"] as? Float
            Task { @MainActor in
                guard DeviceSync.shared.commandID == requestID else { return }
                DeviceSync.shared.remoteBusy = false; DeviceSync.shared.commandTask?.cancel()
                if let data { DeviceSync.shared.receivePlayback(data) }
                if let volume { DeviceSync.shared.remoteVolume = volume }
            }
        }, errorHandler: { _ in
            Task { @MainActor in guard DeviceSync.shared.commandID == requestID else { return }; DeviceSync.shared.remoteBusy = false; DeviceSync.shared.remoteMessage = "iPhone에 전달하지 못했어요. 다시 시도해 주세요." }
        })
        commandTask?.cancel()
        commandTask = Task { try? await Task.sleep(for: .seconds(10)); guard !Task.isCancelled, commandID == requestID else { return }; remoteBusy = false; remoteMessage = "iPhone 응답이 늦어요. 연결을 확인해 주세요." }
        #endif
    }
    func performCommand(_ action: String, station: Station?, minutes: Int?, volume: Float? = nil) {
        #if os(iOS) && !WIDGET_EXTENSION
        #if DEBUG
        UserDefaults.standard.set(["action": action, "time": Date.now.timeIntervalSince1970] as [String: Any], forKey: "debug-applied-command")
        #endif
        switch action {
        case "play": if let station { RadioPlayer.shared.play(station) }
        case "pause": RadioPlayer.shared.pause()
        case "resume": RadioPlayer.shared.resume()
        case "airplay":
            if let station, RadioPlayer.shared.station?.catalogKey != station.catalogKey || !RadioPlayer.shared.isPlaying { RadioPlayer.shared.play(station) }
            NotificationCenter.default.post(name: Notification.Name("onAirShowAirPlay"), object: nil)
        case "volume": if let volume, volume.isFinite { RadioPlayer.shared.volume = min(1, max(0, volume)) }
        case "sleep": RadioPlayer.shared.setSleep(minutes: minutes == 0 ? nil : minutes)
        default: break
        }
        #endif
    }
}
#if os(iOS) || os(watchOS)
// WCSession's Objective-C callback is transferred once to the main actor.
private final class ReplyBox: @unchecked Sendable {
    let reply: ([String: Any]) -> Void
    init(_ reply: @escaping ([String: Any]) -> Void) { self.reply = reply }
}
private final class WatchBridgeDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in DeviceSync.shared.phoneReachable = reachable; DeviceSync.shared.publishPlayback(SharedStore.read()) }
        receive(session.receivedApplicationContext)
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in DeviceSync.shared.phoneReachable = reachable; if reachable { DeviceSync.shared.publishPlayback(SharedStore.read()) } }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    private func receive(_ context: [String: Any]) {
        let favorites = context["favorites"] as? Data; let playback = context["playback"] as? Data
        Task { @MainActor in
            if let favorites { DeviceSync.shared.receiveFavorites(favorites) }
            if let playback { DeviceSync.shared.receivePlayback(playback) }
        }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let action = message["action"] as? String ?? "status"
        let station = (message["station"] as? Data).flatMap { try? JSONDecoder().decode(Station.self, from: $0) }
        let minutes = message["minutes"] as? Int
        let volume = message["volume"] as? Float
        let reply = ReplyBox(replyHandler)
        Task { @MainActor in
            DeviceSync.shared.performCommand(action, station: station, minutes: minutes, volume: volume)
            var response: [String: Any] = ["playback": (try? JSONEncoder().encode(SharedStore.read())) ?? Data()]
            #if os(iOS) && !WIDGET_EXTENSION
            response["volume"] = RadioPlayer.shared.volume
            #endif
            reply.reply(response)
        }
    }
}
#endif
