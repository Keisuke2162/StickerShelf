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
        case .shelf:
            ShelfView(container: container, router: router)
        case .pile:
            PileView(container: container, router: router)
        case .calendar:
            CalendarView(container: container, router: router)
        case .settings:
            MyPageView(container: container)
        }
    }

    private func applyStartScreen() {
        guard let screen = startupOptions.startScreen else { return }
        switch screen {
        case .shelf:
            router.selectedTab = .shelf
        case .pile:
            router.selectedTab = .pile
        case .calendar:
            router.selectedTab = .calendar
        case .settings:
            router.selectedTab = .settings
        case .add:
            router.isAddingBook = true
        case .detail:
            router.selectedTab = .shelf
            Task {
                let boards = (try? await container.fetchBoards.execute(kind: .shelf)) ?? []
                for board in boards {
                    if let first = try? await container.fetchShelf.execute(boardID: board.id).books.first {
                        router.detailBookID = first.id
                        break
                    }
                }
            }
        }
    }
}

private struct DetailBookWrapper: Identifiable, Hashable {
    let id: BookID
}

#endif
