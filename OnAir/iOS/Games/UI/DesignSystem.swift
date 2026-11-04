import SwiftUI

enum Palette {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.13)
    static let indigo = Color(red: 0.21, green: 0.25, blue: 0.29)
    static let teal = Color(red: 0.70, green: 0.27, blue: 0.13)
    static let mint = Color(red: 0.74, green: 0.78, blue: 0.70)
    static let lavender = Color(red: 0.77, green: 0.77, blue: 0.75)
    static let coral = Color(red: 0.91, green: 0.52, blue: 0.31)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let line = Color(red: 0.85, green: 0.84, blue: 0.81)
}
struct AmbientBackground: View {
    var body: some View {
        Palette.paper.ignoresSafeArea()
    }
}
struct GameScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let rules: String
    let restart: () -> Void
    let undo: (() -> Void)?
    var compactBoard = false
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false
    @State private var showRestart = false
    var body: some View {
        ScrollView {
            VStack(spacing: compactBoard ? 10 : 18) {
                if compactBoard {
                    HStack { Text(title).font(.title3.bold()); Spacer(); Text(subtitle).font(.system(size:9,weight:.medium)).foregroundStyle(.secondary) }.padding(.top,4)
                } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle().fill(Palette.teal).frame(width: 6, height: 6)
                        Text(subtitle).font(.caption2.weight(.semibold)).tracking(1.7).foregroundStyle(.secondary)
                    }
                    Text(title).font(.system(size: 33, weight: .semibold, design: .rounded)).tracking(-1.3).foregroundStyle(Palette.ink)
                    Rectangle().fill(Palette.line).frame(height: 1).padding(.top, 3)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
                content
                HStack(spacing: 14) {
                    if let undo {
                        Button(action: undo) { Label("되돌리기", systemImage: "arrow.uturn.backward") }.buttonStyle(.glass).accessibilityIdentifier("game.undo")
                    }
                    Button { showRestart = true } label: { Label("새 게임", systemImage: "arrow.clockwise") }.buttonStyle(.glass).accessibilityIdentifier("game.restart")
                }.padding(.bottom, 28)
            }.padding(.horizontal, compactBoard ? 8 : 24).frame(maxWidth: compactBoard ? 860 : 660).frame(maxWidth: .infinity)
        }
        .background(AmbientBackground())
        .environment(\.colorScheme, .light)
        .navigationTitle(title == "마법 체스" ? "체스" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("플레이로 돌아가기").accessibilityIdentifier("game-back") } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showRules = true } label: { Image(systemName: "questionmark") }.accessibilityLabel("게임 규칙").accessibilityIdentifier("game.rules") } }
        .sheet(isPresented: $showRules) {
            NavigationStack {
                ScrollView { VStack(alignment: .leading, spacing: 20) { Text(title).font(.largeTitle.bold()); Text(rules).font(.body).lineSpacing(8) }.padding(28) }
                    .background(AmbientBackground()).navigationTitle("플레이 가이드").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { showRules = false } } }
            }.presentationDetents([.medium, .large])
        }
        .confirmationDialog("진행 중인 게임을 끝내고 새로 시작할까요?", isPresented: $showRestart, titleVisibility: .visible) { Button("새 게임 시작", role: .destructive, action: restart) }
    }
}
struct StatusPill: View {
    let text: String
    var color: Color = Palette.indigo
    var body: some View { Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 20).padding(.vertical, 12).background(color.opacity(0.08), in: Capsule()).accessibilityAddTraits(.updatesFrequently) }
}

func restoreGame<T: Codable>(_ type: T.Type, key: String, fallback: @autoclosure () -> T) -> T {
    guard let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode(type, from: data) else { return fallback() }
    if let value = value as? any SavedGameValidation, !value.validSession { return fallback() }
    return value
}
func saveGame<T: Codable>(_ value: T, key: String) {
    if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
}
