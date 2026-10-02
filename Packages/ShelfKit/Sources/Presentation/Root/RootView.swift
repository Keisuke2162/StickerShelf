#if canImport(UIKit)
import SwiftUI
import Domain

public struct RootView: View {
    private let container: PresentationContainer
    private let startupOptions: StartupOptions
    @State private var router = Router()

    public init(container: PresentationContainer, startupOptions: StartupOptions = .init()) {
        self.container = container
        self.startupOptions = startupOptions
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
                .padding(.bottom, 84)
            CustomTabBar(router: router)
        }
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .sheet(item: Binding(
            get: { router.detailBookID.map(DetailBookWrapper.init(id:)) },
            set: { router.detailBookID = $0?.id }
        )) { wrapper in
            BookDetailSheet(
                container: container,
                bookID: wrapper.id,
                router: router
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $router.isAddingBook) {
            AddBookView(container: container, router: router)
        }
        .task {
            applyStartScreen()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch router.selectedTab {
        case .board:
            if router.boardMode == .shelf {
                ShelfView(container: container, router: router)
            } else {
                PileView(container: container, router: router)
            }
        case .calendar:
            CalendarView(container: container, router: router)
        case .settings:
            SettingsView(container: container)
        }
    }

    private func applyStartScreen() {
        guard let screen = startupOptions.startScreen else { return }
        switch screen {
        case .shelf:
            router.selectedTab = .board
            router.boardMode = .shelf
        case .pile:
            router.selectedTab = .board
            router.boardMode = .pile
        case .calendar:
            router.selectedTab = .calendar
        case .settings:
            router.selectedTab = .settings
        case .add:
            router.isAddingBook = true
        case .detail:
            router.selectedTab = .board
            router.boardMode = .shelf
            // 詳細は本が1冊でもあればそれを表示。無ければ何もしない。
            Task {
                if let first = try? await container.fetchShelf.execute(filter: .all).books.first {
                    router.detailBookID = first.id
                }
            }
        }
    }
}

private struct DetailBookWrapper: Identifiable, Hashable {
    let id: BookID
}

#endif
