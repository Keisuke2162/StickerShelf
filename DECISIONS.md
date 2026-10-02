# 判断ログ（仕様に無い点の決定）

- 2026-10-02: カラートークンの Asset Catalog は Presentation モジュールの `Resources/Assets.xcassets` に置き、`Bundle.module` 経由で参照する。App ターゲットから色を触らないため Preview/Test が自己完結する。
- 2026-10-02: フォント（Dela Gothic One / Zen Kaku Gothic New）の TTF ファイルはこのサンドボックスでは取得できないため、Phase 0 では `Font.custom` で参照しつつ、見つからない場合は `Font.system` にフォールバックする実装にする。TTF が揃った段階で `UIAppFonts` を Info.plist に追加すれば差し替わる。
- 2026-10-02: App ターゲットは `@main` と `AppContainer` のみを含み、画面コードは Presentation モジュールに置く。既存の `ContentView.swift` / `Item.swift` は削除し、`StickerShelfApp` から `RootView(container:)` を呼ぶ。
- 2026-10-02: ShelfKit パッケージは `Domain / Application / Infrastructure / Presentation` の 4 ターゲット＋同数のテストターゲットで分割し、依存方向を Package.swift で強制する。
- 2026-10-02: Secrets は `Secrets.example.xcconfig` を雛形としてリポジトリに置き、実鍵は `Secrets.xcconfig`（.gitignore 対象）に書く。Phase 2 で `GOOGLE_BOOKS_API_KEY` を Info.plist 経由で読み込む仕組みを足す。
- 2026-10-02: `Book.changeStatus` を「→ unread 遷移時に `progress.currentPage = 0`」に揃える。Notion 01 では明記されていないが、進捗は読書中にのみ意味を持つため。
- 2026-10-02: Notion 03 の `SearchPreferenceRepository` は `var restrictToJapanese: Bool { get set }` だが、Swift 6 の Sendable プロトコルでは mutable property が不便なため `restrictToJapanese()` / `setRestrictToJapanese(_:)` の関数対に変更した。
- 2026-10-02: `TsundokuStatistics.addedThisMonth` は Notion 03 の「`addedAt` が当月」記述に素直に従い、ステータスでフィルタせず全書籍の addedAt が当月のものを数える。Pile 画面のラベルは「今月増えた n冊」。
- 2026-10-02: `Book` の初期化は検証つき `init(throws)` と再構築用 `Book.reconstruct(...)` の 2 経路に分ける。再構築経路は SwiftData Mapper 側が正当性を担保する。
- 2026-10-02: `StickerPlacement.init` は値を silently clamp する（Notion 03 の記載通り）。永続層からの復元で保存値が範囲外だと復元位置が動くため、Mapper で保存値の範囲検証を行うこと。
