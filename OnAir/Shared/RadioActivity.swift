#if os(iOS)
import ActivityKit
struct RadioActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stationName: String
        var isPlaying: Bool
        var buffering: Bool
    }
    var stationID: String
}
#endif
