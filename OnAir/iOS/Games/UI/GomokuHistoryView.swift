import SwiftUI

struct GomokuHistoryView: View {
    @Binding var records: [GomokuRecord]
    let current: GomokuRecord?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current {
                    Section("지금 두는 판") {
                        NavigationLink { GomokuReplayDetail(record: current) } label: {
                            recordRow(current, currentGame: true)
                        }
                    }
                }
                Section("지난 대국 · \(records.count)") {
                    if records.isEmpty {
                        ContentUnavailableView("아직 지난 대국이 없어요", systemImage: "clock.arrow.circlepath", description: Text("한 판을 마치거나 새 게임을 시작하면 여기에 남아요."))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(records) { record in
                        NavigationLink { GomokuReplayDetail(record: record) } label: {
                            recordRow(record, currentGame: false)
                        }
                    }
                    .onDelete { offsets in
                        records.remove(atOffsets: offsets)
                        GomokuHistory.save(records)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AmbientBackground())
            .navigationTitle("오목 대국 기록")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
    }

    private func recordRow(_ record: GomokuRecord, currentGame: Bool) -> some View {
        HStack(spacing: 13) {
            Image(systemName: currentGame ? "circle.dotted.circle.fill" : "circle.grid.cross")
                .font(.title3).foregroundStyle(Palette.teal)
                .frame(width: 38, height: 38)
                .background(Palette.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(currentGame ? "진행 중인 대국" : record.result).font(.subheadline.bold())
                Text("\(record.opponent) · \(record.moves.count)수").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !currentGame {
                Text(record.playedAt.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR"))))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct GomokuReplayDetail: View {
    let record: GomokuRecord
    @State private var step: Int
    @AppStorage("gomoku.showLastMove") private var showLastMove = true

    init(record: GomokuRecord) {
        self.record = record
        _step = State(initialValue: record.moves.count)
    }

    private var position: GomokuGame { record.position(after: step) }
    private var theme: GomokuTheme { GomokuTheme(rawValue: record.theme) ?? .wood }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text(record.result).font(.title2.bold()).foregroundStyle(Palette.ink)
                    Text("\(record.opponent) · \(record.playedAt.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "ko_KR"))))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                GomokuBoard(game: position, theme: theme, showLastMove: showLastMove, cellIdentifierPrefix: "gomoku.replay.cell")
                VStack(spacing: 13) {
                    HStack {
                        Text(step == 0 ? "대국 시작" : "\(step) / \(record.moves.count)수")
                            .font(.subheadline.bold()).monospacedDigit()
                        Spacer()
                        if step > 0 {
                            Text(step.isMultiple(of: 2) ? "백돌이 둔 수" : "흑돌이 둔 수")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Slider(value: Binding(get: { Double(step) }, set: { step = Int($0) }), in: 0...Double(max(1, record.moves.count)), step: 1)
                        .tint(Palette.teal)
                        .accessibilityIdentifier("gomoku.replay.slider")
                    HStack(spacing: 12) {
                        Button { step = max(0, step - 1) } label: { Label("이전 수", systemImage: "chevron.left") }
                            .disabled(step == 0)
                            .accessibilityIdentifier("gomoku.replay.previous")
                        Spacer()
                        Button { step = min(record.moves.count, step + 1) } label: { Label("다음 수", systemImage: "chevron.right") }
                            .disabled(step == record.moves.count)
                            .accessibilityIdentifier("gomoku.replay.next")
                    }
                    .buttonStyle(.glass)
                }
                .padding(18)
                .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(22)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .background(AmbientBackground())
        .navigationTitle("한 수씩 복기")
        .navigationBarTitleDisplayMode(.inline)
    }
}
