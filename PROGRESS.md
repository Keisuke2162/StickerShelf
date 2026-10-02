STATUS: IN_PROGRESS

## タスク

### Phase 0：プロジェクト準備
- [x] Notion 01〜05 を読み、05 の全チェック項目と「完了の定義」をここに転記する
- [x] scripts/verify.sh を本実装（iPhone シミュレータ自動選択・ビルド・全テスト・警告ゼロ判定）
- [x] Xcode プロジェクト設定（iOS 17+、Swift 6、Light 固定）と pbxproj の整合
- [x] `Packages/ShelfKit` ローカルパッケージを作成し、Domain / Application / Infrastructure / Presentation ターゲットとテストターゲットを定義
- [ ] フォント（Dela Gothic One、Zen Kaku Gothic New）を同梱し `UIAppFonts` に登録（TTF 入手後に対応、DECISIONS 参照）
- [x] Asset Catalog にカラートークンを登録（Presentation の Resources に配置、Bundle.module 経由）
- [x] Info.plist：`NSCameraUsageDescription`、`NSPhotoLibraryUsageDescription`、`UIUserInterfaceStyle = Light`
- [x] `Secrets.example.xcconfig` と `.gitignore`（`Secrets.xcconfig`）
- [x] App ターゲットを ShelfKit に依存させ、@main / AppContainer / Resources のみに整理
- [ ] DEBUG 用の起動引数（`-SeedSampleData`、`-StartScreen`、`-UseStubCatalog`）の受け口を用意（Phase 4 で実装）

### Phase 1：Domain
- [x] 値オブジェクト（ISBN, ReadingStatus, ReadingPeriod, ReadingProgress, StickerPlacement, StickerEdge, BookMetadata, PurchaseInfo, CoverImage, APIKey, BookID, CatalogBook）
- [x] `Book` 集約とドメインルール
- [x] ドメインサービス（StickerPlacementFactory, TsundokuStatistics, ReadingCalendar）
- [x] リポジトリプロトコル（BookRepository, BookCatalogRepository, APIKeyRepository, CoverImageRepository, SearchPreferenceRepository）
- [x] DomainError
- [x] DomainTests

### Phase 2：Infrastructure
- [x] SwiftData：BookRecord / Mapper / SwiftDataBookRepository（@ModelActor）
- [x] Google Books：DTO / Mapper / Client / ErrorMapper / GoogleBooksCatalogRepository
- [x] KeychainAPIKeyRepository（Secrets.xcconfig フォールバック込み）
- [x] FileCoverImageRepository / ImageLoader
- [x] UserDefaultsSearchPreferenceRepository
- [x] InfrastructureTests（JSONフィクスチャ・URLProtocolスタブ）

### Phase 3：Application
- [ ] 03 ページの UseCase 一覧をすべて実装（SearchCatalog, FindCatalogBookByISBN, AddBook, FetchShelf, FetchPile, FetchReadingCalendar, FetchBookDetail, UpdateBookDetail, ChangeReadingStatus, MoveSticker, BringStickerToFront, ReplaceCoverImage, DeleteBook, SaveAPIKey, DeleteAPIKey, LoadAPIKeyStatus, TestCatalogConnection）
- [ ] ApplicationTests

### Phase 4：Presentation
- [ ] DesignSystem：Color/Font トークン、`StickerView`（3種の縁）、`GeneratedCoverView`、`CoverImageView`（非同期）、チップ、セグメント
- [ ] RootView ＋ カスタムタブバー ＋ Router ＋ AppContainer
- [ ] 設定画面（APIキー・接続テスト・日本語限定トグル・ライセンス）
- [ ] 本を追加（検索・ISBN・バーコード・手動登録・置き場所選択）
- [ ] 本棚ボード（ジェスチャ：移動・拡縮・回転・最前面・長押しメニュー、フィルタ、貼るアニメ）
- [ ] 積読（SpriteKit の山表示・リスト表示・集計・長押しメニュー）
- [ ] 詳細モーダル（全項目編集・検証エラー表示・書影差し替え・削除）
- [ ] カレンダー（月移動・書影表示・日付選択リスト・集計）
- [ ] 各画面の空状態・読み込み中・エラー表示
- [ ] DEBUG 用の起動引数（StartScreen / SeedSampleData / UseStubCatalog）対応

### Phase 5：仕上げ
- [ ] Reduce Motion 対応、VoiceOver ラベル、Dynamic Type 確認
- [ ] ステッカー100枚のパフォーマンス（60fps）確認
- [ ] SwiftUI Preview がネットワーク・永続化なしで全画面表示
- [ ] README.md（ビルド手順、APIキー設定方法、アーキテクチャ図）

## 完了の定義（受け入れ基準）
- [ ] APIキー未設定で「宇宙」と検索すると結果が出る（クォータ超過時は設定への案内）
- [ ] 設定でAPIキーを保存して「接続テスト」が ✓、以降のリクエストに `key` が付く
- [ ] バーコード読み取り→積読で追加→積読画面の上から落ちてくる
- [ ] 積読の本を長押し→「読み始める」で本棚に貼られ、開始日が今日
- [ ] 本棚のステッカーを移動・回転・拡縮・重ねた状態がアプリ再起動後も復元
- [ ] 詳細で読了日を入れて保存→カレンダーの該当日に書影が表示
- [ ] 書影が無い本は生成カバーで表示、写真で差し替えられる
- [ ] 機内モードでも登録済みの本と書影が全て表示
- [ ] 全テストが通り、Swift 6 の警告がゼロ

## レビュー指摘

### Phase 1 (spec-reviewer, 2026-10-02)
- [x] [high] `Book.changeStatus` が検証前に `status`/`sticker`/`progress` を代入してから `period.isValid()` で throw するため、失敗時に副作用が残る。候補値をローカルで組み立て、全検証通過後にまとめて self に代入する。
- [x] [high] reading→finished で `startedAt > today` のとき `finishedAt=today` 自動補完 → invalidPeriod を throw するが book は status だけ変わる。候補 period で検証後に代入する実装にし、「status は reading のまま」のテストを追加。
- [x] [medium] `Book.init` が `(status == .unread) == (sticker == nil)` の不変条件を検証していない。再構築用も含めて不整合データを拒否するか、構築経路を分ける。
- [x] [medium] `ReadingProgress.init(currentPage:)` が負値を黙って 0 に丸める。`Book.updateProgress` と挙動が食い違うので `init?` または throws にする。
- [x] [medium] `TsundokuStatistics.addedThisMonth` が unread のみを対象にしており Notion 03 の記述（status 絞らず addedAt が当月）と差異。仕様をどちらに寄せ、テストを揃える。
- [x] [medium] Book のステータス遷移テストに finished→reading / finished→unread / unread→finished で既存 finishedAt あり / reading→finished で startedAt が未来 / pageCount=nil で finished / moveSticker 成功ケースが不足。
- [x] [medium] ISBN テストに lowercase x の 10 桁、979 プレフィックス 13 桁、X が末尾以外のパターンを追加。
- [x] [medium] StickerPlacement の clamp 挙動を docstring に明記（復元時に値が動く可能性）。
- [x] [low] DECISIONS に `→ unread 遷移時 progress もリセット` と `SearchPreferenceRepository を関数化（Sendable 対応）` を追記。
