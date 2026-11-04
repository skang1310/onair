import SwiftUI

struct BoardQuickMenu<Landscape: View, Settings: View>: View {
    let title: String
    @Binding var showLastMove: Bool
    let canUndo: Bool
    let undo: () -> Void
    let restart: () -> Void
    @ViewBuilder let landscape: Landscape
    @ViewBuilder let settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var confirmRestart = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if page != 0 { Button { page = 0 } label: { Image(systemName:"chevron.left") }.buttonStyle(.glass).accessibilityIdentifier("boardMenu.back") }
                Text(page == 0 ? title + " 보드 메뉴" : page == 1 ? "풍경" : "게임 설정").font(.title3.bold())
                Spacer()
                Button { dismiss() } label: { Image(systemName:"xmark") }.buttonStyle(.glass).accessibilityLabel("메뉴 닫기").accessibilityIdentifier("boardMenu.close")
            }.padding(.bottom, 4)
            if page == 0 {
                row("풍경", symbol:"mountain.2", id:"boardMenu.landscape") { page = 1 }
                row("설정", symbol:"slider.horizontal.3", id:"boardMenu.settings") { page = 2 }
                Toggle(isOn:$showLastMove) { Label("직전 수 표시",systemImage:"scope") }.font(.subheadline.weight(.medium)).tint(Palette.teal).padding(.horizontal,14).frame(minHeight:48).accessibilityIdentifier("boardMenu.showLastMove")
                Divider().padding(.horizontal, 8)
                row("되돌리기", symbol:"arrow.uturn.backward", id:"boardMenu.undo") { undo(); dismiss() }.disabled(!canUndo)
                row("새 게임", symbol:"arrow.clockwise", id:"boardMenu.restart") { confirmRestart = true }
            } else {
                ScrollView {
                    VStack(spacing:18) { if page == 1 { landscape } else { settings } }.padding(.vertical,8)
                }
            }
        }
        .padding(20).frame(maxWidth:660)
        .frame(maxWidth:.infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius:30))
        .padding(12)
        .presentationBackground(.clear)
        .presentationDetents(page == 0 ? [.height(430)] : [.large])
        .presentationDragIndicator(.hidden)
        .confirmationDialog("현재 판을 끝내고 새 게임을 시작할까요?",isPresented:$confirmRestart,titleVisibility:.visible) {
            Button("새 게임 시작",role:.destructive) { restart(); dismiss() }.accessibilityIdentifier("boardMenu.confirmRestart")
            Button("취소",role:.cancel) { }
        }
    }
    private func row(_ title:String, symbol:String, id:String, action:@escaping ()->Void) -> some View {
        Button(action:action) {
            HStack(spacing:14) { Image(systemName:symbol).frame(width:24).foregroundStyle(Palette.teal); Text(title); Spacer(); if title == "풍경" || title == "설정" { Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary) } }
                .font(.subheadline.weight(.medium)).padding(.horizontal,14).frame(minHeight:48).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(Palette.ink).accessibilityIdentifier(id)
    }
}
