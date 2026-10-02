import SwiftUI
import Presentation

@main
struct StickerShelfApp: App {
    @State private var container: AppContainer

    init() {
        _container = State(initialValue: AppContainer.makeDefault())
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
