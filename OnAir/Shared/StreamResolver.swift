import Foundation

enum StreamResolver {
    private struct KBSResponse: Decodable {
        struct Item: Decodable { let service_url: String; let media_type: String }
        let channel_item: [Item]
    }
    static func freshAddressAPI(for station: Station) -> URL? {
        let mbc = ["mbcstandard": "sfm", "mbcfm4u": "mfm", "mbcallthat": "chm"]
        if let code = mbc[station.catalogKey] { return URL(string: "https://sminiplay.imbc.com/aacplay.ashx?agent=webapp&channel=\(code)") }
        let sbs = ["sbspower": "powerpc/powerfm", "sbslove": "lovepc/lovefm"]
        if let channel = sbs[station.catalogKey] { return URL(string: "https://apis.sbs.co.kr/play-api/1.0/livestream/\(channel)?protocol=hls&ssl=Y") }
        return nil
    }
    static func kbsChannelCode(for station: Station) -> String? {
        ["kbs1radio": "21", "kbs2r": "22", "kbs3r": "23", "kbsclassicfm": "24", "kbscoolfm": "25"][station.catalogKey]
    }
    static func parseAddress(_ data: Data) throws -> URL {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), url.scheme == "https", let host = url.host,
              host.hasSuffix(".imbc.com") || host.hasSuffix(".sbs.co.kr") else { throw URLError(.cannotDecodeContentData) }
        return url
    }
    static func resolve(_ station: Station) async throws -> URL {
        if let api = freshAddressAPI(for: station) {
            var request = URLRequest(url: api, cachePolicy: .reloadIgnoringLocalCacheData); request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return try parseAddress(data)
        }
        if let code = kbsChannelCode(for: station) {
            let url = URL(string: "https://cfpwwwapi.kbs.co.kr/api/v1/landing/live/channel_code/\(code)")!
            var request = URLRequest(url: url); request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let value = try JSONDecoder().decode(KBSResponse.self, from: data)
            guard let item = value.channel_item.first(where: { $0.media_type == "radio" }), let stream = URL(string: item.service_url), stream.scheme == "https" else { throw URLError(.badURL) }
            return stream
        }
        guard let stream = station.streamURL else { throw URLError(.badURL) }
        return stream
    }
}
