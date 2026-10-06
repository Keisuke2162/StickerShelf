#if canImport(UIKit)
import SwiftUI
import Domain

public struct RootView: View {
    private let container: PresentationContainer
    private let startupOptions: StartupOptions
    @State private var router = Router()
    @State private var themeStore: ThemeStore
    @State private var pileAllFolderStore = PileAllFolderAppearanceStore()

    public init(container: PresentationContainer, startupOptions: StartupOptions = .init()) {
        self.container = container
        self.startupOptions = startupOptions
        self._themeStore = State(initialValue: ThemeStore(repository: container.themePreferences))
        Self.configureTabBarAppearance()
    }

    /// タブバーの選択/非選択アイコン・ラベル色を控えめなコントラストに固定する。
    /// SwiftUI の .tint だけでは「選択=その色、非選択=自動で薄め」になり、
    /// パレットによっては選択/非選択どちらかが濃すぎたり薄すぎたりするため。
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let selected = UIColor(white: 0.28, alpha: 1.0)
        let unselected = UIColor(white: 0.70, alpha: 1.0)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = unselected
        item.normal.titleTextAttributes = [.foregroundColor: unselected]
        item.selected.iconColor = selected
        item.selected.titleTextAttributes = [.foregroundColor: selected]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        // iOS 26 以降は TabView を使うと Liquid Glass デザインが自動適用される。
        // タブの選択状態は @Observable の Router を @Bindable 経由で Binding に変換。
        @Bindable var routerBinding = router
        return TabView(selection: $routerBinding.selectedTab) {
            ShelfView(container: container, router: router)
                .tabItem { Label("本棚", systemImage: "square.on.square") }
                .tag(Router.Tab.shelf)

            PileView(container: container, router: router)
                .tabItem { Label("積読", systemImage: "square.stack.3d.down.right") }
                .tag(Router.Tab.pile)

            CalendarView(container: container, router: router)
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(Router.Tab.calendar)

            MyPageView(container: container, router: router)
                .tabItem { Label("マイページ", systemImage: "person.circle") }
                .tag(Router.Tab.settings)
        }
        // 色は configureTabBarAppearance で UITabBarAppearance 経由に固定している。
        .environment(themeStore)
        .environment(pileAllFolderStore)
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
            // sheet の content は親の環境値を自動継承しない組み合わせがあるため、明示注入する。
            .environment(themeStore)
            .environment(pileAllFolderStore)
        }
        .fullScreenCover(isPresented: $router.isAddingBook) {
            NavigationStack {
                AddBookView(container: container, router: router)
            }
            .environment(themeStore)
            .environment(pileAllFolderStore)
        }
        .task {
            applyStartScreen()
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
