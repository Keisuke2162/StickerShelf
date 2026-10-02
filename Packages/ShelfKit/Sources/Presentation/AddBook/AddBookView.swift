#if canImport(UIKit)
import SwiftUI
import Domain
import Application

public struct AddBookView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: AddBookViewModel
    @State private var showScanner = false
    @State private var showManualEntry = false
    @Environment(\.dismiss) private var dismiss

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: AddBookViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchBar
                    if viewModel.isSearching {
                        ProgressView()
                    }
                    if let error = viewModel.errorMessage, !viewModel.isSearching {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(FontToken.bodyRegular())
                                .foregroundStyle(ColorToken.sunday)
                                .multilineTextAlignment(.leading)
                            Button("手動で登録する") { showManualEntry = true }
                                .buttonStyle(.borderedProminent)
                                .tint(ColorToken.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
                    } else if !viewModel.results.isEmpty {
                        resultsList
                    } else if !viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSearching {
                        VStack(spacing: 8) {
                            Text("見つかりませんでした").font(FontToken.bodyRegular()).foregroundStyle(ColorToken.inkSecondary)
                            Button("手動で登録する") { showManualEntry = true }
                                .buttonStyle(.borderedProminent)
                                .tint(ColorToken.accent)
                        }
                        .frame(maxWidth: .infinity).padding()
                    }
                    destinationPicker
                    DatePicker("購入日", selection: $viewModel.purchasedAt, displayedComponents: .date)
                }
                .padding(20)
            }
            .background(ColorToken.boardBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ColorToken.boardBackground)
            }
            .navigationTitle("本を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { isbn in
                    showScanner = false
                    Task { await viewModel.lookupISBN(isbn) }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView { entry in
                    Task {
                        if await viewModel.addManual(entry: entry) != nil {
                            router.selectedTab = .board
                            router.boardMode = viewModel.destination == .unread ? .pile : .shelf
                            showManualEntry = false
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorToken.inkSecondary)
                TextField("タイトル・著者・ISBN", text: $viewModel.keyword, onEditingChanged: { _ in })
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.keyword) { _, _ in
                        viewModel.onKeywordChanged()
                    }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))

            Button { showScanner = true } label: {
                Image(systemName: "barcode.viewfinder")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.ink))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("バーコード読み取り")
        }
    }

    private var resultsList: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, item in
                Button {
                    if !item.alreadyRegistered {
                        viewModel.selectedCatalog = item.catalog
                    }
                } label: {
                    HStack(spacing: 12) {
                        CoverImageView(
                            cover: item.catalog.metadata.remoteCoverURL.map(CoverImage.remote) ?? .none,
                            title: item.catalog.metadata.title,
                            loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
                        )
                        .frame(width: 40, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.catalog.metadata.title).font(FontToken.sectionTitle()).foregroundStyle(ColorToken.ink).lineLimit(2)
                            if !item.catalog.metadata.authors.isEmpty {
                                Text(item.catalog.metadata.authors.joined(separator: ", "))
                                    .font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary).lineLimit(1)
                            }
                            if let page = item.catalog.metadata.pageCount {
                                Text("\(page)ページ").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                            }
                        }
                        Spacer()
                        if item.alreadyRegistered {
                            Text("登録済み").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                        } else if viewModel.selectedCatalog?.metadata.catalogID == item.catalog.metadata.catalogID {
                            Image(systemName: "checkmark").foregroundStyle(ColorToken.accent)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.selectedCatalog?.metadata.catalogID == item.catalog.metadata.catalogID ? ColorToken.ink : .clear, lineWidth: 2)
                    )
                    .opacity(item.alreadyRegistered ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(item.alreadyRegistered)
            }
        }
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("どこに置く？").font(FontToken.sectionTitle())
            HStack(spacing: 8) {
                destinationCard(.reading, title: "読んでる", description: "ボードに貼る")
                destinationCard(.finished, title: "読んだ", description: "貼って日付記録")
                destinationCard(.unread, title: "積読", description: "下に落とす")
            }
        }
    }

    private func destinationCard(_ destination: AddBookViewModel.Destination, title: String, description: String) -> some View {
        let selected = viewModel.destination == destination
        return Button {
            viewModel.destination = destination
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(FontToken.sectionTitle()).foregroundStyle(ColorToken.ink)
                Text(description).font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? ColorToken.accentSoft : ColorToken.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? ColorToken.accent : ColorToken.hairline, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var actionButton: some View {
        let label: String = {
            switch viewModel.destination {
            case .reading: return "ボードに貼る"
            case .finished: return "読了として貼る"
            case .unread: return "積読ゾーンに落とす"
            }
        }()
        return Button {
            Task {
                if await viewModel.addSelected() != nil {
                    // Notion 02 S-05「追加後はシートを閉じ、置き場所に応じて本棚 or 積読を表示」
                    router.selectedTab = .board
                    router.boardMode = viewModel.destination == .unread ? .pile : .shelf
                    dismiss()
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
