#!/usr/bin/env bash
# cc-window-hud 卸载器：撤 tmux 底栏 + shell wrapper，停所有 cc-watch，清运行态缓存。
set -uo pipefail

MARK=">>> cc-window-hud >>>"
MARKEND="<<< cc-window-hud <<<"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cc-window-hud"

strip_block() {
  local f="$1"; [ -f "$f" ] || return 0
  awk -v a="# $MARK" -v b="# $MARKEND" '
    $0 ~ a {s=1} !s{print} $0 ~ b {s=0}' "$f" > "$f.cchud.tmp" && mv "$f.cchud.tmp" "$f"
}

for f in "$HOME/.tmux.conf" "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
  strip_block "$f"
done

# 停所有 cc-watch 进程
pkill -f "$STATE_DIR" 2>/dev/null || true
pkill -f 'cc-watch'   2>/dev/null || true
rm -rf "$STATE_DIR/pid"

# 复位 tmux 底栏（清 status-right 里的脚本调用）
if [ -n "${TMUX:-}" ]; then
  tmux set -gu status-right 2>/dev/null || true
  tmux set -gu status-interval 2>/dev/null || true
  tmux set-hook -gu after-new-window    2>/dev/null || true
  tmux set-hook -gu after-select-window 2>/dev/null || true
  tmux set-hook -gu pane-focus-in       2>/dev/null || true
fi

echo "✅ 已卸载 cc-window-hud（tmux 底栏 + wrapper 已撤，watcher 已停）"
echo "→ 标题缓存保留在 $STATE_DIR/title（如需清：rm -rf \"$STATE_DIR\"）"
echo "→ 当前 shell 里 wrapper 函数仍在，重开 shell 或 unset -f claude codex 清除"
