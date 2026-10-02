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
