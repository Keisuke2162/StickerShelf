#if canImport(UIKit)
import SwiftUI
import Domain
import Application

public struct ManualEntryView: View {
    @State private var title: String = ""
    @State private var authors: String = ""
    @State private var publisher: String = ""
    @State private var pageCount: String = ""
    @State private var isbnText: String = ""
    public let onSubmit: (AddBookInput.ManualEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onSubmit: @escaping (AddBookInput.ManualEntry) -> Void) {
        self.onSubmit = onSubmit
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("本の情報") {
                    TextField("タイトル（必須）", text: $title)
                    TextField("著者（カンマ区切り）", text: $authors)
                    TextField("出版社", text: $publisher)
                    TextField("ページ数", text: $pageCount).keyboardType(.numberPad)
                    TextField("ISBN", text: $isbnText).keyboardType(.numberPad)
                }
            }
            .navigationTitle("手動で登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let entry = AddBookInput.ManualEntry(
                            title: title,
                            authors: authors.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                            publisher: publisher.isEmpty ? nil : publisher,
                            pageCount: Int(pageCount),
                            isbn: ISBN(isbnText)
                        )
                        onSubmit(entry)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#endif
