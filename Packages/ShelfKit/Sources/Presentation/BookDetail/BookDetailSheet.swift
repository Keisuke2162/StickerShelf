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
    @State private var showDocumentScanner = false
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
            VStack(alignment: .center, spacing: 20) {
                heroCover(book: book)
                titleBlock(book: book)
                statusSegment(draft: draft)
                boardPicker(draft: draft)
                dateGrid(draft: draft)
                edgePicker(draft: draft)
                coverReplace()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(ColorToken.ink)
                }
                .accessibilityLabel("閉じる")
            }
        }
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
        .fullScreenCover(isPresented: $showDocumentScanner) {
            DocumentScannerView(
                onCapture: { image in
                    showDocumentScanner = false
                    // VisionKit は四角検出 + 遠近補正済みの UIImage を返すので、そのまま JPEG で保存。
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        Task { await viewModel.replaceCover(data: data) }
                    }
                },
                onCancel: { showDocumentScanner = false }
            )
            .ignoresSafeArea()
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

    /// 書影を上部中央にリッチに表示（140×200）。
    private func heroCover(book: Book) -> some View {
        StickerView(
            cover: book.cover,
            title: book.metadata.title,
            edge: book.stickerEdge,
            size: CGSize(width: 140, height: 200),
            loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
        )
        .rotationEffect(.degrees(-4))
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    private func titleBlock(book: Book) -> some View {
        VStack(spacing: 4) {
            Text(book.metadata.title)
                .font(FontToken.bookTitleLarge())
                .foregroundStyle(ColorToken.ink)
                .multilineTextAlignment(.center)
            if !book.metadata.authors.isEmpty {
                Text(book.metadata.authors.joined(separator: ", "))
                    .font(FontToken.bodyRegular())
                    .foregroundStyle(ColorToken.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 「本棚／積読」の 2 ボタン。本棚側の中で「読んでる／読んだ」はフォルダ選択で決まる仕様。
    private func statusSegment(draft: Binding<BookDetailDraft>) -> some View {
        let isShelf = draft.wrappedValue.status != .unread
        return HStack(spacing: 4) {
            segmentButton(title: "本棚", isSelected: isShelf) {
                if draft.wrappedValue.status == .unread {
                    // 積読から本棚へ戻すときは「読んでる」を既定にする。
                    draft.wrappedValue.status = .reading
                    // boardID はピッカー描画時に shelf 側の既定へ寄せる（下記 onChange）。
                    draft.wrappedValue.boardID = defaultBoardID(for: .reading)
                }
            }
            segmentButton(title: "積読", isSelected: !isShelf) {
                if draft.wrappedValue.status != .unread {
                    draft.wrappedValue.status = .unread
                    draft.wrappedValue.boardID = defaultBoardID(for: .unread)
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.segmentTrack))
    }

    private func segmentButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FontToken.sectionTitle())
                .foregroundStyle(isSelected ? .white : ColorToken.inkSecondary)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? ColorToken.accent : .clear))
        }
        .buttonStyle(.plain)
    }

    /// セグメント切替時のフォルダ既定。「読んでる」「読んだ」など同名の shelf フォルダがあれば優先。
    private func defaultBoardID(for status: ReadingStatus) -> BoardID? {
        let kind: BoardKind = status == .unread ? .pile : .shelf
        let candidates = viewModel.boards.filter { $0.kind == kind }
        if status == .reading, let hit = candidates.first(where: { $0.name == "読んでる" }) { return hit.id }
        if status == .finished, let hit = candidates.first(where: { $0.name == "読んだ" }) { return hit.id }
        return candidates.first?.id
    }

    /// 本棚フォルダ選択時に、既定名ならステータスを連動して切り替える。
    private func syncStatusWithShelfBoard(_ board: Board, draft: Binding<BookDetailDraft>) {
        guard board.kind == .shelf else { return }
        switch board.name {
        case "読んでる":
            draft.wrappedValue.status = .reading
        case "読んだ":
            draft.wrappedValue.status = .finished
        default:
            // カスタム本棚フォルダは status を変えない（現在 .reading / .finished のまま）。
            if draft.wrappedValue.status == .unread {
                draft.wrappedValue.status = .reading
            }
        }
    }

    private func dateGrid(draft: Binding<BookDetailDraft>) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            dateCell(title: "購入日", date: Binding(get: { draft.wrappedValue.purchasedAt }, set: { draft.wrappedValue.purchasedAt = $0 }))
            dateCell(title: "読了日", date: Binding(get: { draft.wrappedValue.finishedAt }, set: { draft.wrappedValue.finishedAt = $0 }))
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

    private func boardPicker(draft: Binding<BookDetailDraft>) -> some View {
        let status = draft.wrappedValue.status
        let targets = viewModel.boards(for: status)
        let title = status == .unread ? "積読フォルダ" : "本棚"
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FontToken.sectionTitle())
            if targets.isEmpty {
                Text(status == .unread ? "フォルダ未作成（未分類で保存されます）" : "本棚がありません。先に本棚を作成してください。")
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.inkSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "未分類", isSelected: draft.wrappedValue.boardID == nil) {
                            draft.wrappedValue.boardID = nil
                        }
                        ForEach(targets) { board in
                            Chip(title: board.name, isSelected: draft.wrappedValue.boardID == board.id) {
                                draft.wrappedValue.boardID = board.id
                                syncStatusWithShelfBoard(board, draft: draft)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func edgeLabel(_ edge: StickerEdge) -> String {
        switch edge { case .white: return "白フチ"; case .none: return "フチなし"; case .holo: return "ホロ" }
    }

    private func coverReplace() -> some View {
        HStack(spacing: 8) {
            Button {
                showDocumentScanner = true
            } label: {
                Label("カメラで撮影", systemImage: "camera.viewfinder")
                    .font(FontToken.sectionTitle())
                    .foregroundStyle(ColorToken.ink)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(ColorToken.hairline, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("カメラで書影を撮影")

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("アルバムから", systemImage: "photo.on.rectangle")
                    .font(FontToken.sectionTitle())
                    .foregroundStyle(ColorToken.ink)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(ColorToken.hairline, lineWidth: 1.5))
            }
            .accessibilityLabel("アルバムから書影を選ぶ")
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
