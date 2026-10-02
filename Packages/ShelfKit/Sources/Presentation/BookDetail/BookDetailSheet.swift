#if canImport(UIKit)
import SwiftUI
import PhotosUI
import Domain
import Application

public struct BookDetailSheet: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: BookDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var pickerItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    public init(container: PresentationContainer, bookID: BookID, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: BookDetailViewModel(container: container, bookID: bookID))
    }

    public var body: some View {
        NavigationStack {
            if let book = viewModel.book, let draft = Binding(
                get: { viewModel.draft },
                set: { viewModel.draft = $0 }
            ).unwrapOptional() {
                content(book: book, draft: draft)
            } else {
                ProgressView().task { await viewModel.load() }
            }
        }
    }

    @ViewBuilder
    private func content(book: Book, draft: Binding<BookDetailDraft>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerRow(book: book)
                statusSegment(draft: draft)
                progressSection(book: book, draft: draft)
                dateGrid(draft: draft)
                memoSection(draft: draft)
                edgePicker(draft: draft)
                coverReplace()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButtons()
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ColorToken.boardBackground)
        }
        .alert("この本を削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                Task {
                    if await viewModel.delete() { dismiss() }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                    await viewModel.replaceCover(data: data)
                }
            }
        }
        .alert(
            "保存に失敗しました",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }

    private func headerRow(book: Book) -> some View {
        HStack(alignment: .top, spacing: 16) {
            StickerView(
                cover: book.cover,
                title: book.metadata.title,
                edge: book.stickerEdge,
                size: CGSize(width: 98, height: 140),
                loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
            )
            .rotationEffect(.degrees(-4))
            VStack(alignment: .leading, spacing: 4) {
                Text(book.metadata.title).font(FontToken.bookTitleLarge()).foregroundStyle(ColorToken.ink)
                if !book.metadata.authors.isEmpty {
                    Text(book.metadata.authors.joined(separator: ", "))
                        .font(FontToken.bodyRegular()).foregroundStyle(ColorToken.inkSecondary)
                }
                if let publisher = book.metadata.publisher {
                    Text(publisher).font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                }
                if let pages = book.metadata.pageCount {
                    Text("\(pages)ページ").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                }
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark").frame(width: 44, height: 44)
                    .background(Circle().fill(ColorToken.surfaceMuted))
                    .foregroundStyle(ColorToken.ink)
            }
            .buttonStyle(.plain)
        }
    }

    private func statusSegment(draft: Binding<BookDetailDraft>) -> some View {
        HStack(spacing: 4) {
            ForEach([ReadingStatus.unread, .reading, .finished], id: \.self) { status in
                Button {
                    draft.wrappedValue.status = status
                } label: {
                    Text(statusLabel(status))
                        .font(FontToken.sectionTitle())
                        .foregroundStyle(draft.wrappedValue.status == status ? .white : ColorToken.inkSecondary)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(draft.wrappedValue.status == status ? ColorToken.accent : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.segmentTrack))
    }

    private func statusLabel(_ status: ReadingStatus) -> String {
        switch status { case .unread: return "積読"; case .reading: return "読んでる"; case .finished: return "読んだ" }
    }

    @ViewBuilder
    private func progressSection(book: Book, draft: Binding<BookDetailDraft>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("進捗").font(FontToken.sectionTitle())
                Spacer()
                if let total = book.metadata.pageCount {
                    Text("\(draft.wrappedValue.currentPage) / \(total) p").font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
                }
            }
            if let total = book.metadata.pageCount, total > 0 {
                ProgressView(value: Double(draft.wrappedValue.currentPage), total: Double(total))
                    .tint(ColorToken.accent)
                Stepper("現在ページ", value: Binding(
                    get: { draft.wrappedValue.currentPage },
                    set: { draft.wrappedValue.currentPage = max(0, min(total, $0)) }
                ), in: 0...total, step: 1)
                .labelsHidden()
            } else {
                TextField("現在ページ", value: Binding(
                    get: { draft.wrappedValue.currentPage },
                    set: { draft.wrappedValue.currentPage = max(0, $0) }
                ), formatter: NumberFormatter())
                .keyboardType(.numberPad)
            }
        }
    }

    private func dateGrid(draft: Binding<BookDetailDraft>) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            dateCell(title: "購入日", date: Binding(get: { draft.wrappedValue.purchasedAt }, set: { draft.wrappedValue.purchasedAt = $0 }))
            dateCell(title: "読み始めた日", date: Binding(get: { draft.wrappedValue.startedAt }, set: { draft.wrappedValue.startedAt = $0 }))
            dateCell(title: "読了日", date: Binding(get: { draft.wrappedValue.finishedAt }, set: { draft.wrappedValue.finishedAt = $0 }))
            textCell(title: "購入場所", text: Binding(get: { draft.wrappedValue.purchasePlace }, set: { draft.wrappedValue.purchasePlace = $0 }))
        }
    }

    private func dateCell(title: String, date: Binding<Date?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
            HStack(spacing: 6) {
                if let bound = date.wrappedValue {
                    DatePicker("", selection: Binding(get: { bound }, set: { date.wrappedValue = $0 }), displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    Button(action: { date.wrappedValue = nil }) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(ColorToken.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("日付をクリア")
                } else {
                    Text("未設定").foregroundStyle(ColorToken.inkTertiary)
                    Spacer()
                    Button("設定") { date.wrappedValue = Date() }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorToken.accent)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).stroke(ColorToken.hairline, lineWidth: 1.5))
        }
    }

    private func textCell(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
            TextField("", text: text)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).stroke(ColorToken.hairline, lineWidth: 1.5))
        }
    }

    private func memoSection(draft: Binding<BookDetailDraft>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("メモ").font(FontToken.sectionTitle())
            TextEditor(text: Binding(get: { draft.wrappedValue.memo }, set: { draft.wrappedValue.memo = $0 }))
                .frame(minHeight: 84)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12).stroke(ColorToken.hairline, lineWidth: 1.5))
        }
    }

    private func edgePicker(draft: Binding<BookDetailDraft>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ステッカーの縁").font(FontToken.sectionTitle())
            HStack(spacing: 8) {
                ForEach([StickerEdge.white, .none, .holo], id: \.self) { edge in
                    Button {
                        draft.wrappedValue.stickerEdge = edge
                    } label: {
                        Text(edgeLabel(edge))
                            .font(FontToken.label())
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(ColorToken.surface))
                            .overlay(Capsule().stroke(draft.wrappedValue.stickerEdge == edge ? ColorToken.ink : ColorToken.hairline, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorToken.ink)
                }
            }
        }
    }

    private func edgeLabel(_ edge: StickerEdge) -> String {
        switch edge { case .white: return "白フチ"; case .none: return "フチなし"; case .holo: return "ホロ" }
    }

    private func coverReplace() -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("書影を差し替え", systemImage: "photo.on.rectangle")
                .font(FontToken.sectionTitle())
                .foregroundStyle(ColorToken.ink)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).stroke(ColorToken.hairline, lineWidth: 1.5))
        }
    }

    private func bottomButtons() -> some View {
        HStack(spacing: 12) {
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(ColorToken.sunday)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surfaceMuted))
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    if await viewModel.save() { dismiss() }
                }
            } label: {
                Text(viewModel.isSaving ? "保存中..." : "保存")
                    .font(FontToken.sectionTitle())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.ink))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaving)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

private extension Binding where Value == BookDetailDraft? {
    func unwrapOptional() -> Binding<BookDetailDraft>? {
        guard let value = self.wrappedValue else { return nil }
        return Binding<BookDetailDraft>(
            get: { self.wrappedValue ?? value },
            set: { self.wrappedValue = $0 }
        )
    }
}

#endif
