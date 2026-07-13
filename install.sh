#!/usr/bin/env bash
# tui-agent-hud 安装器
#   1) tmux 底栏 HUD：status-right 调 agent-hud-title + status-interval 5
#   2) shell wrapper：claude / codex 启动时后台挂一个只盯本窗的 agent-watch（兼容 cc+codex）
# 幂等：用块标记，重复跑只刷新自己的块，不重复追加。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$ROOT/bin"
MARK=">>> tui-agent-hud >>>"
MARKEND="<<< tui-agent-hud <<<"

# 删掉文件里旧的 tui-agent-hud 块（含边界行）——awk 实现，跨 GNU/BSD 可移植
strip_block() {
  local f="$1"; [ -f "$f" ] || return 0
  awk -v a="# $MARK" -v b="# $MARKEND" '
    $0 ~ a {s=1} !s{print} $0 ~ b {s=0}' "$f" > "$f.cchud.tmp" && mv "$f.cchud.tmp" "$f"
}

# 1) tmux 底栏
TMUXCONF="$HOME/.tmux.conf"
strip_block "$TMUXCONF"
cat >> "$TMUXCONF" <<EOF
# $MARK
# 底栏显示当前窗「红绿灯 + 编号 + 任务标题」；红绿灯由每窗 agent-watch 自监听维护
set -g status-right-length 90
set -g status-interval 5
set -g status-right ' #[fg=black]#($BIN/agent-hud-title)#[default]   %H:%M'
# 兜底自启（wrapper 之外）：新窗/切窗/聚焦时确保当前窗挂 watcher；幂等，非 cc/codex 窗自退
set-hook -g after-new-window    'run-shell -b "$BIN/agent-watch #{pane_id}"'
set-hook -g after-select-window 'run-shell -b "$BIN/agent-watch #{pane_id}"'
set-hook -g pane-focus-in       'run-shell -b "$BIN/agent-watch #{pane_id}"'
# $MARKEND
EOF

# 2) shell wrapper（兼容 cc + codex）
detect_profile() {
  case "${SHELL:-}" in
    *zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    *bash) echo "$HOME/.bashrc" ;;
    *)     echo "$HOME/.profile" ;;
  esac
}
PROFILE="$(detect_profile)"
strip_block "$PROFILE"
cat >> "$PROFILE" <<EOF
# $MARK
export PATH="$BIN:\$PATH"
# 起 claude / codex 时后台挂一个只盯本窗的 agent-watch（幂等、窗关自退、只改自己窗名）
claude() { [ -n "\${TMUX:-}" ] && ( "$BIN/agent-watch" >/dev/null 2>&1 & ); command claude "\$@"; }
codex()  { [ -n "\${TMUX:-}" ] && ( "$BIN/agent-watch" >/dev/null 2>&1 & ); command codex "\$@"; }
# $MARKEND
EOF

# 3) 即时生效 tmux 底栏
# 用 tmux info 检测 server 是否在跑（不依赖 $TMUX 环境变量——它不继承到本安装子进程）
if tmux info >/dev/null 2>&1; then
  tmux source-file "$TMUXCONF" 2>/dev/null && echo "✅ tmux 底栏 + hook 已即时生效"
fi
echo "✅ wrapper 已装到 ${PROFILE}（兼容 claude + codex）"
echo "→ 当前 shell 生效：source \"${PROFILE}\""
echo "→ 已开的 cc/codex 窗要挂上监听：在该窗跑一次  $BIN/agent-watch &"
