# 読書ステッカーボード iOS アプリ — 自律実装ルール

## 仕様の正
Notion「読書管理アプリ」とその配下 01〜05 が唯一の仕様。
https://app.notion.com/p/3edcce9226cc80318f8feace8c6723b4
仕様と矛盾する実装をしない。仕様に無い点は合理的に決め、DECISIONS.md に1行で記録する。
人間への質問はしない（ユーザーは不在）。迷ったら決めて記録し、先へ進む。

## 進捗管理
- PROGRESS.md がタスクの唯一の管理表。先頭行は `STATUS: IN_PROGRESS` / `STATUS: DONE` / `STATUS: BLOCKED`
- 05「実装計画」の全チェック項目と「完了の定義」を PROGRESS.md に転記して使う
- レビュー指摘は PROGRESS.md の「## レビュー指摘」に `- [ ]` で追記し、他のタスクと同様に消化する
- コンテキストが長くなったら PROGRESS.md と DECISIONS.md を読み直してから続ける

## ループ（完了まで繰り返す）
1. PROGRESS.md の未完了タスクを上から1つ選ぶ
2. 実装する（テストも同時に書く）
3. `scripts/verify.sh` を実行。失敗したら原因を直して緑になるまで繰り返す
4. チェックを付けて git commit（Conventional Commits、日本語可）
5. フェーズの最後のタスクを終えたら：
   - spec-reviewer サブエージェントに「Phase N のレビュー」を依頼
   - Phase 4 以降は ui-reviewer サブエージェントにも画面レビューを依頼
   - 返ってきた指摘のうち重大度 high / medium を「## レビュー指摘」に追加して消化する
6. 全タスク完了後：spec-reviewer に「全体の最終レビュー」、ui-reviewer に「全画面の最終レビュー」を依頼。
   high / medium の指摘が 0 件になるまで 1〜5 を繰り返す
7. 指摘 0 件・verify.sh 緑・未完了 0 件になったら、PROGRESS.md 先頭を `STATUS: DONE` にして最終報告を書く

## BLOCKED にしてよいのは次の場合だけ
Notion を読めない、Xcode / Simulator が動かない等、人間の操作なしに先へ進めないとき。
PROGRESS.md 先頭を `STATUS: BLOCKED` にし、理由と人間にやってほしいことを書いて止まる。

## 技術ルール（詳細は Notion 03）
- iOS 17+ / Swift 6 Strict Concurrency / SwiftUI / SwiftData / 外部ライブラリなし
- DDD × Clean Architecture × MVVM。依存は Domain へ一方向（ローカル Swift Package のターゲットで強制）
- コードはほぼ全てローカル Swift Package（ShelfKit）に置き、App ターゲットは @main・AppContainer・リソースだけにする。
  こうすると project.pbxproj をほとんど触らずに済む。XcodeGen 等の外部ツールは使わない。
  pbxproj を編集したら必ず verify.sh で xcodebuild が通ることを確認する
- verify.sh は「ビルド＋全テスト＋Swift 6 警告ゼロ」を判定する
- レビュー用に DEBUG ビルド限定の起動引数を用意する：
  `-SeedSampleData YES`（モックと同等のサンプル本 18冊＋積読 23冊を投入）
  `-StartScreen shelf|pile|calendar|detail|add|settings`（起動直後にその画面を表示）
  `-UseStubCatalog YES`（書籍検索をネットワークなしのスタブに差し替え）
