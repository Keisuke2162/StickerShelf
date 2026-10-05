#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// 本を追加フローの共通フッター：本棚/積読セグメント + フォルダピッカー + 追加ボタン。
/// 追加完了時は対応するタブへ `router.selectedTab` を切り替える。
struct AddBookFooter: View {
    @Bindable var viewModel: AddBookViewModel
    let router: Router

    @State private var showCreateBoard = false
    @State private var newBoardName = ""

    var body: some View {
        VStack(spacing: 10) {
            destinationSegment
            boardPicker
            actionButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(ColorToken.boardBackground)
        .alert(viewModel.destination == .shelf ? "新しい本棚を作成" : "新しい積読フォルダを作成", isPresented: $showCreateBoard) {
            TextField(viewModel.destination == .shelf ? "本棚の名前" : "フォルダ名", text: $newBoardName)
            Button("作成") {
                let name = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let captured = name
                Task {
                    await viewModel.createBoard(name: captured)
                    newBoardName = ""
                }
            }
            Button("キャンセル", role: .cancel) { newBoardName = "" }
        }
    }

    private var destinationSegment: some View {
        HStack(spacing: 4) {
            destinationSegmentButton(.shelf, title: "本棚")
            destinationSegmentButton(.pile, title: "積読")
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.segmentTrack))
    }

    private func destinationSegmentButton(_ destination: AddBookViewModel.Destination, title: String) -> some View {
        let selected = viewModel.destination == destination
        return Button {
            viewModel.destination = destination
        } label: {
            Text(title)
                .font(FontToken.sectionTitle())
                .foregroundStyle(selected ? .white : ColorToken.inkSecondary)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? ColorToken.accent : .clear))
        }
        .buttonStyle(.plain)
    }

    private var boardPicker: some View {
        let isShelf = viewModel.destination == .shelf
        let addLabel = isShelf ? "本棚を追加" : "フォルダを追加"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !isShelf {
                    Chip(title: "未分類", isSelected: viewModel.selectedPileBoardID == nil) {
                        viewModel.selectedPileBoardID = nil
                    }
                }
                ForEach(viewModel.boardsForCurrentDestination) { board in
                    let selected = (isShelf ? viewModel.selectedShelfBoardID : viewModel.selectedPileBoardID) == board.id
                    Chip(title: board.name, isSelected: selected) {
                        if isShelf { viewModel.selectedShelfBoardID = board.id }
                        else { viewModel.selectedPileBoardID = board.id }
                    }
                }
                Button {
                    showCreateBoard = true
                } label: {
                    Label(addLabel, systemImage: "plus")
                        .font(FontToken.label())
                        .foregroundStyle(ColorToken.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(ColorToken.surface))
                        .overlay(Capsule().stroke(ColorToken.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }

    private var actionButton: some View {
        let label = viewModel.destination == .pile ? "積読ゾーンに落とす" : "本棚に貼る"
        return Button {
            Task {
                if await viewModel.addSelected() != nil {
                    // タブ画面として動くので dismiss せず対応タブへ遷移。
                    router.selectedTab = viewModel.destination == .pile ? .pile : .shelf
                }
            }
        } label: {
            Text(viewModel.isAdding ? "追加中..." : label)
                .font(FontToken.sectionTitle())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 16).fill(ColorToken.accent))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedCatalog == nil || viewModel.isAdding)
        .opacity(viewModel.selectedCatalog == nil ? 0.5 : 1.0)
    }
}

#endif
