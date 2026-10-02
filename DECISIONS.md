# 判断ログ（仕様に無い点の決定）

- 2026-10-02: カラートークンの Asset Catalog は Presentation モジュールの `Resources/Assets.xcassets` に置き、`Bundle.module` 経由で参照する。App ターゲットから色を触らないため Preview/Test が自己完結する。
- 2026-10-02: フォント（Dela Gothic One / Zen Kaku Gothic New）の TTF ファイルはこのサンドボックスでは取得できないため、Phase 0 では `Font.custom` で参照しつつ、見つからない場合は `Font.system` にフォールバックする実装にする。TTF が揃った段階で `UIAppFonts` を Info.plist に追加すれば差し替わる。
- 2026-10-02: App ターゲットは `@main` と `AppContainer` のみを含み、画面コードは Presentation モジュールに置く。既存の `ContentView.swift` / `Item.swift` は削除し、`StickerShelfApp` から `RootView(container:)` を呼ぶ。
- 2026-10-02: ShelfKit パッケージは `Domain / Application / Infrastructure / Presentation` の 4 ターゲット＋同数のテストターゲットで分割し、依存方向を Package.swift で強制する。
- 2026-10-02: Secrets は `Secrets.example.xcconfig` を雛形としてリポジトリに置き、実鍵は `Secrets.xcconfig`（.gitignore 対象）に書く。Phase 2 で `GOOGLE_BOOKS_API_KEY` を Info.plist 経由で読み込む仕組みを足す。
