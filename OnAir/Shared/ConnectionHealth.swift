import Foundation
import Observation

struct ConnectionResult: Codable, Sendable {
    enum State: String, Codable { case checking, reachable, unavailable }
    var state: State
    var checkedAt: Date
    var detail: String
    var label: String {
        switch state { case .checking: "확인 중"; case .reachable: "응답 확인"; case .unavailable: "연결 확인 필요" }
    }
}
@MainActor @Observable final class ConnectionHealth {
    static let shared = ConnectionHealth()
    var results: [String: ConnectionResult] = [:]
    func check(_ station: Station, force: Bool = false) async {
        if let result = results[station.id], result.state == .checking || (!force && Date.now.timeIntervalSince(result.checkedAt) < 600) { return }
        results[station.id] = .init(state: .checking, checkedAt: .now, detail: "방송 서버를 확인합니다")
        do {
            let url = try await StreamResolver.resolve(station)
            var request = URLRequest(url: url); request.timeoutInterval = 10
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            var prefix = Data()
            for try await byte in bytes { prefix.append(byte); if prefix.count >= 1024 { break } }
            guard !prefix.isEmpty else { throw URLError(.zeroByteResource) }
            let text = String(decoding: prefix, as: UTF8.self)
            let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            guard !contentType.contains("text/html"), !text.hasPrefix("OggS"), !text.lowercased().contains("<!doctype html") else { throw URLError(.cannotDecodeContentData) }
            if text.contains("#EXTM3U") {
                guard let line = text.split(whereSeparator: \.isNewline).first(where: { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
                      let mediaURL = URL(string: String(line), relativeTo: url)?.absoluteURL else { throw URLError(.cannotDecodeContentData) }
                var mediaRequest = URLRequest(url: mediaURL); mediaRequest.timeoutInterval = 10
                let (mediaBytes, mediaResponse) = try await URLSession.shared.bytes(for: mediaRequest)
                guard let mediaHTTP = mediaResponse as? HTTPURLResponse, (200...299).contains(mediaHTTP.statusCode), !(mediaHTTP.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/html") else { throw URLError(.badServerResponse) }
                var hasBytes = false
                for try await _ in mediaBytes { hasBytes = true; break }
                guard hasBytes else { throw URLError(.zeroByteResource) }
            }
            if url.pathExtension.lowercased() == "m3u8", !String(decoding: prefix, as: UTF8.self).contains("#EXTM3U") { throw URLError(.cannotDecodeContentData) }
            results[station.id] = .init(state: .reachable, checkedAt: .now, detail: "서버 응답 확인 · 실제 재생은 네트워크에 따라 달라질 수 있어요")
        } catch {
            if Task.isCancelled { results.removeValue(forKey: station.id); return }
            results[station.id] = .init(state: .unavailable, checkedAt: .now, detail: "서버 응답을 확인하지 못했어요. 다시 확인하거나 재생을 시도하세요.")
        }
    }
    func check(_ stations: [Station]) async {
        // Limit concurrent network requests; do not scan all broadcasters on launch.
        for station in stations { if Task.isCancelled { return }; await check(station) }
    }
}

enum ReconnectPolicy {
    static let delays: [Double] = [2, 5, 10]
    static func delay(for attempt: Int) -> Double? { delays.indices.contains(attempt) ? delays[attempt] : nil }
}
