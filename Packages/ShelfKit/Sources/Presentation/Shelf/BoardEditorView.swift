#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// 本棚ボードの名前・背景色・模様を編集する sheet。
struct BoardEditorView: View {
    let container: PresentationContainer
    let board: Board

    @State private var name: String
    @State private var color: BoardColor
    @State private var pattern: BoardPattern
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(container: PresentationContainer, board: Board) {
        self.container = container
        self.board = board
        self._name = State(initialValue: board.name)
        self._color = State(initialValue: board.appearance.color)
        self._pattern = State(initialValue: board.appearance.pattern)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("ボード名", text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                Section("背景色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(BoardColor.allCases, id: \.self) { c in
                            colorSwatch(c)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("模様") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        ForEach(BoardPattern.allCases, id: \.self) { p in
                            patternTile(p)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("プレビュー") {
                    BoardBackgroundView(appearance: BoardAppearance(color: color, pattern: pattern))
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(ColorToken.hairline, lineWidth: 1))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(FontToken.caption())
                        .foregroundStyle(ColorToken.sunday)
                }
            }
            .navigationTitle("ボードを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func colorSwatch(_ c: BoardColor) -> some View {
        Button {
            color = c
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(BoardAppearanceStyle.background(c))
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color == c ? ColorToken.accent : ColorToken.hairline, lineWidth: color == c ? 3 : 1))
                Text(c.displayName)
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.ink)
            }
        }
        .buttonStyle(.plain)
    }

    private func patternTile(_ p: BoardPattern) -> some View {
        Button {
            pattern = p
        } label: {
            VStack(spacing: 6) {
                BoardBackgroundView(appearance: BoardAppearance(color: color, pattern: p))
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(pattern == p ? ColorToken.accent : ColorToken.hairline, lineWidth: pattern == p ? 3 : 1))
                Text(p.displayName)
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.ink)
            }
        }
        .buttonStyle(.plain)
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await container.updateBoard.execute(
                id: board.id,
                name: trimmed,
                appearance: BoardAppearance(color: color, pattern: pattern)
            )
            dismiss()
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }
}

#endif
