import SwiftUI
import UniformTypeIdentifiers

struct FavoriteReorderDrop: DropDelegate {
    let target: String
    @Binding var dragging: String?
    let library: StationLibrary
    func validateDrop(info: DropInfo) -> Bool { dragging != nil }
    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.easeInOut(duration: 0.2)) { library.reorderFavorite(dragging, before: target) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragging = nil; return true }
}
