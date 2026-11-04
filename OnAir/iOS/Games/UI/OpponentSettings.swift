import SwiftUI

struct OpponentSettings: View {
    let computer: Bool
    let difficulty: String
    let start: (Bool, String) -> Void
    @State private var showSettings = false
    var body: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: computer ? "desktopcomputer" : "person.2.fill").font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(computer ? "컴퓨터와 대결" : "가족과 2인 플레이").font(.subheadline.bold())
                    Text(computer ? "나는 선공 · \(ComputerDifficulty(rawValue: difficulty)?.title ?? "보통")" : "아이폰을 건네며 번갈아 두세요").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(); Image(systemName: "slider.horizontal.3")
            }.padding(16).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).foregroundStyle(Palette.teal).accessibilityIdentifier("opponent.settings")
        .sheet(isPresented: $showSettings) {
            OpponentSetupSheet(computer: computer, difficulty: difficulty) { useComputer, level in
                start(useComputer, level); showSettings = false
            }
        }
    }
}

private struct OpponentSetupSheet: View {
    @State private var draftComputer: Bool
    @State private var draftDifficulty: String
    let start: (Bool, String) -> Void
    @Environment(\.dismiss) private var dismiss
    init(computer: Bool, difficulty: String, start: @escaping (Bool, String) -> Void) {
        _draftComputer = State(initialValue: computer)
        _draftDifficulty = State(initialValue: difficulty)
        self.start = start
    }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("누구와 한 판 할까요?").font(.title2.bold())
                Picker("대결 상대", selection: $draftComputer) {
                    Text("가족 2인").tag(false)
                    Text("컴퓨터").tag(true)
                }.pickerStyle(.segmented)
                if draftComputer {
                    Picker("난이도", selection: $draftDifficulty) {
                        ForEach(ComputerDifficulty.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }.pickerStyle(.segmented)
                    Text("내가 먼저 두고 컴퓨터가 다음 수를 둬요. 되돌리기를 누르면 내 수와 컴퓨터의 수를 함께 취소해요.").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("시작하면 현재 판을 끝내고 새 판으로 바뀝니다.").font(.footnote).foregroundStyle(.secondary)
                Button(draftComputer ? "컴퓨터와 새 대결 시작" : "가족과 새 대결 시작") {
                    start(draftComputer, draftDifficulty)
                }.buttonStyle(.glassProminent).accessibilityIdentifier("opponent.start")
                Spacer()
            }.padding(24).background(AmbientBackground()).navigationTitle("대결 설정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }.presentationDetents([.medium,.large])
    }
}
