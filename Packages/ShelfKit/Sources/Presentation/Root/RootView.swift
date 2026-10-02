import SwiftUI

/// アプリの最上位 View。Phase 4 でカスタムタブバーに差し替わる。
public struct RootView<Container>: View {
    private let container: Container

    public init(container: Container) {
        self.container = container
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("StickerShelf")
                .font(.largeTitle.bold())
            Text("準備中")
                .foregroundStyle(.secondary)
        }
    }
}
