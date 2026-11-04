import Foundation

enum RadioFrequency {
    static let values: [String: Double] = ["kbsclassicfm":93.1,"cbsmusic":93.9,"mbcstandard":95.9,"sbslove":103.5,"cbsstandard":98.1,"mbcfm4u":91.9,"sbspower":107.7,"kbscoolfm":89.1,"kbs1radio":97.3,"ytnradio":94.5]
    static func label(_ station: Station?) -> String { station.flatMap { values[$0.catalogKey] }.map { String(format: "%.1f", $0) } ?? "LIVE" }
}
