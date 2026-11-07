#if canImport(UIKit)
import SwiftUI
import Domain

/// 積読の「すべて」フォルダ用の見た目編集 sheet。
/// 「すべて」は実 Board を持たないので、名前・削除は編集対象外。色/模様のみ。
struct AllPileFolderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PileAllFolderAppearanceStore.self) private var store

    @State private var color: BoardColor
    @State private var pattern: BoardPattern

    init(initial: BoardAppearance) {
        self._color = State(initialValue: initial.color)
        self._pattern = State(initialValue: initial.pattern)
    }

    var body: some View {
        NavigationStack {
            Form {
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
            }
            .navigationTitle("「すべて」の見た目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.set(BoardAppearance(color: color, pattern: pattern))
                        dismiss()
                    }
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
}

#endif
