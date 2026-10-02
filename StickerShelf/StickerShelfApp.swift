import SwiftUI
import Presentation

@main
struct StickerShelfApp: App {
    private let container: AppContainer

    init() {
        self.container = AppContainer.makeDefault()
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container.presentation, startupOptions: container.startupOptions)
        }
    }
}
