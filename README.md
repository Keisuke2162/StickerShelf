# StickerShelf

本の書影を「ステッカー」としてボードに貼る iOS 向け読書管理アプリ。本棚ボード・積読（SpriteKit の落ちもの系）・カレンダー・詳細モーダル・本を追加の 5 画面構成。

## 必要環境
- Xcode 16 以上（開発環境では Xcode 27.0 を利用）
- iOS 17.0 以上の iPhone シミュレータ

## ビルドと実行
```bash
export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
# ユニットテスト + アプリビルド + 警告ゼロ判定
bash scripts/verify.sh

# Xcode から起動する場合
open StickerShelf.xcodeproj
```

## プロジェクト構成
```
StickerShelf/
├─ StickerShelf.xcodeproj
├─ StickerShelf/              # App ターゲット（@main と AppContainer のみ）
│  ├─ StickerShelfApp.swift
│  ├─ AppContainer.swift      # Composition Root
│  └─ Assets.xcassets
├─ Packages/
│  └─ ShelfKit/               # ローカル Swift Package（コードの大半）
│     ├─ Sources/
│     │  ├─ Domain/           # 集約・値オブジェクト・ドメインサービス・リポジトリ契約
│     │  ├─ Application/      # UseCase 17 本
│     │  ├─ Infrastructure/   # SwiftData / Google Books / Keychain / 画像
│     │  └─ Presentation/     # SwiftUI + MVVM + SpriteKit + VisionKit
│     └─ Tests/
├─ scripts/verify.sh          # CI 用の緑判定スクリプト
├─ CLAUDE.md                  # 自律実装ルール
├─ PROGRESS.md                # タスク進捗
└─ DECISIONS.md               # 仕様に無い点の決定ログ
```

## アーキテクチャ（DDD × Clean Architecture × MVVM）
依存は常に内側（Domain）へ向く。各層は Swift Package のターゲットで物理的に分離。

```
App (@main / AppContainer / Resources)
  └→ Presentation (SwiftUI + ViewModel)
      └→ Application (UseCase)
          └→ Domain (Entity / Value Object / Repository Protocol)
  └→ Infrastructure (SwiftData / Google Books / Keychain)  → Domain
```

- **Domain** は Foundation のみ依存、全型 `Sendable`
- **Application** の UseCase は 1 ファイル 1 struct、全て `*Protocol` を公開（ViewModel モック化）
- **Infrastructure** は `@ModelActor` ベースの SwiftData リポジトリ、`URLSession` + スタブ対応の Google Books クライアント、`Security` フレームワークの Keychain
- **Presentation** は `@MainActor @Observable final class` の ViewModel + SwiftUI View

## 書籍検索 API (Google Books API)
- APIキーなしでも動作（共有クォータ使用）
- 設定画面でキーを登録すると以降のリクエストに `key` クエリと `X-Ios-Bundle-Identifier` ヘッダが付与される
- 開発時は `Secrets.xcconfig`（git 管理外、`.gitignore` で除外）に `GOOGLE_BOOKS_API_KEY` を書くと `Info.plist` 経由で初期値として読み込む
- Keychain にキーが保存されていれば常にそちらが優先、無ければ xcconfig、両方なければキー無しで送信

### APIキー取得
1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成
2. 「APIとサービス」→「ライブラリ」で Books API を有効化
3. 「認証情報」→「APIキーを作成」→「iOSアプリ」制限で Bundle ID を登録、「API制限」で Books API のみ
4. アプリの設定画面「書籍検索API」→ APIキーを貼り付けて保存 → 接続テストで ✓ を確認

## DEBUG 起動引数（レビュー・開発用）
Xcode の Scheme → Arguments Passed On Launch で指定:
- `-SeedSampleData YES` — 本棚 18 冊 + 積読 23 冊のサンプルデータを in-memory で投入
- `-StartScreen shelf | pile | calendar | detail | add | settings` — 起動直後にその画面を表示
- `-UseStubCatalog YES` — 書籍検索をネットワーク不要なスタブに差し替え

## テスト構成
- `DomainTests` — 43 件（ISBN / Book 遷移 / StickerPlacement / 乱数 / Statistics / Calendar）
- `ApplicationTests` — 24 件（UseCase 単体＋モックリポジトリ）
- `InfrastructureTests` — 39 件（SwiftData in-memory / Google Books JSON フィクスチャ / URLProtocol スタブ / Keychain / FileCover）
- `PresentationTests` — モジュール疎通
- App 側 `StickerShelfTests` / `StickerShelfUITests` — Xcode スキームで実行

`scripts/verify.sh` は iPhone シミュレータの `xcodebuild test` と `swift test` の両方を実行し、警告が 1 件でもあれば exit 1。

## 設計判断ログ
仕様に明記がない点は `DECISIONS.md` に 1 行ずつ記録しています。例えば:
- カラートークンを Presentation モジュールの `Resources/Assets.xcassets` に置き `Bundle.module` 経由で参照
- `Book.changeStatus` は候補値を組み立てて全検証通過後に代入する atomic 実装
- `BookRecord` の全プロパティにデフォルト値を付与して CloudKit 同期準備
- `LoadAPIKeyStatusUseCase` は `APIKeyStatus` enum を返し生キーを View に渡さない

## ライセンス
- フォント: Dela Gothic One / Zen Kaku Gothic New は SIL Open Font License（将来同梱予定）
- アプリ本体のライセンスは TBD
