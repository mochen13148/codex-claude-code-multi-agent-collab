#!/usr/bin/env bash
set -u

PROJECT_ROOT="${AI_COLLAB_ROOT:-$(pwd)}"
COLLAB_DIR="$PROJECT_ROOT/.ai-collab"
SIGNAL_FILE="$COLLAB_DIR/signal/codex-ready"
INBOX_DIR="$COLLAB_DIR/inbox"
THREADS_DIR="$COLLAB_DIR/threads"
LAST_CHECK="$COLLAB_DIR/.last-check"
NOW=$(date +%s)

mkdir -p "$COLLAB_DIR/signal" "$INBOX_DIR" "$THREADS_DIR"

echo "=== $(date +%H:%M:%S) ==="

found=0

if [ -f "$SIGNAL_FILE" ]; then
  echo ">>> Signal <<<"
  found=1
fi

if [ $found -eq 0 ] && [ -f "$LAST_CHECK" ]; then
  LAST_TS=$(cat "$LAST_CHECK")
  for f in "$INBOX_DIR"/*.md; do
    [ -f "$f" ] || continue
    FILE_TS=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    if [ "$FILE_TS" -gt "$LAST_TS" ] 2>/dev/null; then
      if grep -q '^status:[[:space:]]*pending' "$f"; then
        found=1; break
      fi
    fi
  done
  if [ $found -eq 0 ]; then
    for f in "$THREADS_DIR"/*.md; do
      [ -f "$f" ] || continue
      FILE_TS=$(stat -c %Y "$f" 2>/dev/null || echo 0)
      if [ "$FILE_TS" -gt "$LAST_TS" ] 2>/dev/null; then
        found=1; break
      fi
    done
  fi
fi

echo "$NOW" > "$LAST_CHECK"

if [ $found -eq 1 ]; then
  THREAD=""
  if [ -f "$SIGNAL_FILE" ]; then
    THREAD=$(grep -oE '(\.ai-collab/)?threads/[^[:space:]]+\.md' "$SIGNAL_FILE" 2>/dev/null | head -1 || true)
    THREAD=${THREAD#".ai-collab/"}
    [ -n "$THREAD" ] && THREAD="$COLLAB_DIR/${THREAD}"
  fi
  [ -z "$THREAD" ] || [ ! -f "$THREAD" ] && THREAD=$(ls -t "$THREADS_DIR"/*.md 2>/dev/null | head -1)

  if [ -n "$THREAD" ] && [ -f "$THREAD" ]; then
    ROUND=$(grep -oP '^## Round \K[0-9]+' "$THREAD" | tail -1)
    echo ">>> $(basename "$THREAD") Round $ROUND <<<"
    echo ""
    # 只输出 frontmatter + 最新 round
    awk '
      BEGIN { in_fm=0; last_round=""; }
      /^---$/ { if(in_fm==0){in_fm=1; print; next} else if(in_fm==1){in_fm=2; print; next} }
      in_fm==1 { print; next }
      /^## Round / { last_round=$0 "\n"; next }
      { if(length(last_round)>0) last_round=last_round $0 "\n" }
      END { printf "%s", last_round }
    ' "$THREAD"
    echo ""
  fi

  echo "---"
  for f in "$INBOX_DIR"/*.md; do
    [ -f "$f" ] || continue
    if grep -q '^status:[[:space:]]*pending' "$f"; then
      echo "[inbox] $(basename "$f")"
      sed -n '/^---$/,/^---$/p; /^## 内容/,$p' "$f" | head -30
    fi
  done

  rm -f "$SIGNAL_FILE"
else
  echo "WAITING"
fi
