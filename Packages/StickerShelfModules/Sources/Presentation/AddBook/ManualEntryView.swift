#if canImport(UIKit)
import SwiftUI
import UIKit
import Domain
import Application

public struct ManualEntryView: View {
    @State private var title: String = ""
    @State private var authors: String = ""
    @State private var publisher: String = ""
    @State private var pageCount: String = ""
    @State private var isbnText: String = ""
    @State private var coverImageData: Data?
    @State private var showScanner = false

    public let onSubmit: (AddBookInput.ManualEntry, Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onSubmit: @escaping (AddBookInput.ManualEntry, Data?) -> Void) {
        self.onSubmit = onSubmit
    }

    private var isbnValid: Bool {
        isbnText.trimmingCharacters(in: .whitespaces).isEmpty || ISBN(isbnText) != nil
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("書影") {
                    coverSection
                }
                Section {
                    TextField("タイトル（空欄なら「(無題)」）", text: $title)
                    TextField("著者（カンマ区切り、任意）", text: $authors)
                    TextField("出版社（任意）", text: $publisher)
                    TextField("ページ数（任意）", text: $pageCount).keyboardType(.numberPad)
                    TextField("ISBN（任意）", text: $isbnText).keyboardType(.numberPad)
                    if !isbnValid {
                        Text("ISBN の形式が正しくありません").font(FontToken.caption()).foregroundStyle(ColorToken.sunday)
                    }
                } header: {
                    Text("本の情報（すべて任意）")
                }
            }
            .navigationTitle("手動で登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { submit() }
                        .disabled(!isbnValid)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(
                    onCapture: { image in
                        showScanner = false
                        coverImageData = image.jpegData(compressionQuality: 0.9)
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var coverSection: some View {
        HStack(alignment: .center, spacing: 16) {
            coverPreview
                .frame(width: 80, height: 116)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showScanner = true
                } label: {
                    Label(coverImageData == nil ? "書影を撮影" : "撮り直す", systemImage: "camera.viewfinder")
                        .font(FontToken.sectionTitle())
                        .foregroundStyle(ColorToken.ink)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(ColorToken.hairline, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                if coverImageData != nil {
                    Button(role: .destructive) {
                        coverImageData = nil
                    } label: {
                        Label("書影を外す", systemImage: "xmark")
                            .font(FontToken.caption())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorToken.sunday)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let data = coverImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 80, maxHeight: 116)
                .background(ColorToken.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorToken.hairline, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorToken.surfaceMuted)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .foregroundStyle(ColorToken.inkTertiary)
                        Text("未撮影").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ColorToken.hairline, lineWidth: 1))
        }
    }

    private func submit() {
        let effectiveTitle: String = {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(無題)" : trimmed
        }()
        let entry = AddBookInput.ManualEntry(
            title: effectiveTitle,
            authors: authors.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            publisher: publisher.isEmpty ? nil : publisher,
            pageCount: Int(pageCount),
            isbn: ISBN(isbnText)
        )
        onSubmit(entry, coverImageData)
    }
}

#endif
