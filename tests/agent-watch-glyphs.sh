#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# 只加载待测函数，避免启动真正的 tmux watcher。
eval "$(sed -n '/^codex_glyph()/,/^}/p' "$ROOT/bin/agent-watch")"

assert_glyph() {
  local expected="$1"
  local input="$2"
  local actual
  actual=$(codex_glyph "$input")
  if [ "$actual" != "$expected" ]; then
    printf 'expected %s, got %s for: %s\n' "$expected" "$actual" "$input" >&2
    return 1
  fi
}

assert_glyph "🟢" "• Waiting for background terminal"
assert_glyph "🟢" "  • WAITING FOR BACKGROUND TERMINALS (2m 10s)"
assert_glyph "🟡" "› User mentioned: Waiting for background terminal"
assert_glyph "🟢" "• Working (12s • esc to interrupt)"
assert_glyph "🔴" "Would you like to continue?"

echo "agent-watch glyph checks passed"
