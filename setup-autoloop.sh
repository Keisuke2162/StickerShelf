#!/bin/bash
# 読書ステッカーボード：Claude Code 自律実装ループのセットアップ
# 使い方：空の作業フォルダで  bash setup-autoloop.sh
set -euo pipefail

mkdir -p .claude/hooks .claude/agents scripts

# ─────────────────────────────────────────────
# CLAUDE.md（毎セッション自動で読み込まれる作業ルール）
# ─────────────────────────────────────────────
cat > CLAUDE.md <<'EOF'
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
EOF

# ─────────────────────────────────────────────
# PROGRESS.md / DECISIONS.md の雛形
# ─────────────────────────────────────────────
cat > PROGRESS.md <<'EOF'
STATUS: IN_PROGRESS

## タスク
- [ ] Notion 01〜05 を読み、05 の全チェック項目と「完了の定義」をここに転記する
- [ ] scripts/verify.sh を作成し、実行可能にする

## レビュー指摘
EOF

[ -f DECISIONS.md ] || echo "# 判断ログ（仕様に無い点の決定）" > DECISIONS.md

# ─────────────────────────────────────────────
# verify.sh の仮置き（Phase 0 で Claude が本実装に置き換える）
# ─────────────────────────────────────────────
cat > scripts/verify.sh <<'EOF'
#!/bin/bash
# TODO(Claude): Phase 0 で本実装に置き換える。
# 要件：利用可能な iPhone シミュレータを自動選択し、アプリとパッケージをビルド＆全テスト。
#       ビルドログに "warning:" が1件でもあれば失敗扱い。成功時のみ exit 0。
echo "verify.sh is not implemented yet" >&2
exit 1
EOF
chmod +x scripts/verify.sh

# ─────────────────────────────────────────────
# Stop フック：完了条件を満たすまで止まらせない
# ─────────────────────────────────────────────
cat > .claude/hooks/stop-gate.sh <<'EOF'
#!/bin/bash
cd "${CLAUDE_PROJECT_DIR:-.}"
MAX_LOOPS=${AUTOLOOP_MAX:-60}           # 暴走防止の安全弁
COUNT_FILE=.claude/.stop-count
n=$(cat "$COUNT_FILE" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$COUNT_FILE"
if [ "$n" -gt "$MAX_LOOPS" ]; then
  echo "自律ループ上限（${MAX_LOOPS}回）に達したため停止を許可します" >&2
  exit 0
fi

head -1 PROGRESS.md 2>/dev/null | grep -q 'STATUS: BLOCKED' && exit 0

if ! head -1 PROGRESS.md 2>/dev/null | grep -q 'STATUS: DONE'; then
  echo "まだ完了していません（${n}回目）。PROGRESS.md の未完了タスクを CLAUDE.md のループに従って進めてください。人間への質問はせず、判断は DECISIONS.md に記録して続行してください。" >&2
  exit 2
fi

if grep -q '^- \[ \]' PROGRESS.md; then
  echo "STATUS: DONE ですが PROGRESS.md に未完了の項目が残っています。消化してください。" >&2
  exit 2
fi

if ! scripts/verify.sh > .claude/last-verify.log 2>&1; then
  echo "STATUS: DONE ですが scripts/verify.sh が失敗しました。STATUS を IN_PROGRESS に戻して修正してください。ログ末尾：" >&2
  tail -40 .claude/last-verify.log >&2
  exit 2
fi

rm -f "$COUNT_FILE"
exit 0
EOF
chmod +x .claude/hooks/stop-gate.sh

# ─────────────────────────────────────────────
# 権限とフック設定
# ─────────────────────────────────────────────
cat > .claude/settings.json <<'EOF'
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "Bash(xcodebuild:*)",
      "Bash(xcrun:*)",
      "Bash(swift:*)",
      "Bash(git:*)",
      "Bash(scripts/verify.sh:*)",
      "Bash(./scripts/verify.sh:*)",
      "Bash(mkdir:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(plutil:*)",
      "Bash(chmod:*)",
      "Bash(curl:*)",
      "mcp__notion"
    ],
    "deny": [
      "Bash(rm -rf /:*)",
      "Bash(sudo:*)",
      "Bash(git push:*)"
    ]
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/stop-gate.sh",
            "timeout": 1800
          }
        ]
      }
    ]
  }
}
EOF

# ─────────────────────────────────────────────
# サブエージェント：仕様・設計レビュー
# ─────────────────────────────────────────────
cat > .claude/agents/spec-reviewer.md <<'EOF'
---
name: spec-reviewer
description: 実装を Notion の仕様（01〜05）と設計方針に照らしてレビューし、指摘リストを返す。各フェーズ完了時と最終確認で使う。
disallowedTools: Write, Edit, NotebookEdit
model: inherit
---
あなたは iOS アプリの厳しいコードレビュアーです。コードは一切変更せず、指摘だけを返します。

手順：
1. Notion「読書管理アプリ」配下の 01〜05 のうち、依頼されたフェーズに関係するページを読む
   https://app.notion.com/p/3edcce9226cc80318f8feace8c6723b4
2. git log / git diff と該当ソースを読む
3. 次の観点で確認する
   - 仕様の取りこぼし・誤解（要件、ドメインルール、画面仕様の数値、API仕様、受け入れ基準）
   - アーキテクチャ違反（Domain が SwiftData/SwiftUI/URLSession に依存、View が UseCase/Repository を直接呼ぶ、ViewModel にドメインルール、など）
   - Swift 6 並行性の危うさ、強制アンラップ、API キーのログ出力
   - テストの不足（ドメインルールの全分岐、API のエラー変換）
4. 「scripts/verify.sh」を実行して結果も確認する

出力形式（これ以外を書かない）：
- [high|medium|low] ファイル:行 — 問題 — 仕様の根拠（Notion のページ名と項目）— 直し方
指摘が無ければ「指摘なし」とだけ書く。high は「仕様違反・クラッシュ・データ消失・設計違反」、medium は「体験を損なう・テスト不足」、low は好み。
EOF

# ─────────────────────────────────────────────
# サブエージェント：画面レビュー（シミュレータのスクショ確認）
# ─────────────────────────────────────────────
cat > .claude/agents/ui-reviewer.md <<'EOF'
---
name: ui-reviewer
description: シミュレータでアプリを起動して各画面のスクリーンショットを撮り、Notion 02「画面仕様・デザイン」と見比べて指摘を返す。Phase 4 以降と最終確認で使う。
disallowedTools: Write, Edit, NotebookEdit
model: inherit
---
あなたは UI デザインレビュアーです。コードは変更せず、指摘だけを返します。

手順：
1. Notion「02 画面仕様・デザイン」を読む
2. DEBUG ビルドをシミュレータ（iPhone 16 など 390pt 幅の機種）にビルド＆インストールする
3. 画面ごとに次で起動しスクリーンショットを撮る
   xcrun simctl launch --terminate-running-process booted <bundle id> -SeedSampleData YES -UseStubCatalog YES -StartScreen <shelf|pile|calendar|detail|add|settings>
   sleep 3; xcrun simctl io booted screenshot /tmp/ui-<screen>.png
4. Read ツールで各画像を見て、02 の仕様と比較する
   - 配色トークン、フォント（Dela Gothic One / Zen Kaku Gothic New）、余白・角丸・サイズ
   - 本棚：ステッカーが自由配置で重なっている、白フチ・傾き・影、バッジが付いていない
   - 積読：書影が床から積み上がっている、バッジ無し、集計カード
   - カレンダー：読了日に書影、土日色
   - 文字の欠け・はみ出し・重なり、44pt 未満のタップ領域

出力形式（これ以外を書かない）：
- [high|medium|low] 画面名 — 見た目の問題 — 02 の該当仕様 — 直し方の示唆
指摘が無ければ「指摘なし」とだけ書く。
EOF

# git 初期化
if [ ! -d .git ]; then
  git init -q
  printf '.claude/.stop-count\n.claude/last-verify.log\nSecrets.xcconfig\nxcuserdata/\nDerivedData/\n.build/\n' > .gitignore
fi

echo "✅ セットアップ完了。次に：claude を起動して、キックオフの指示を貼ってください。"
