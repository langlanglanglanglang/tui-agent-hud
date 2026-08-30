# tui-agent-hud

给 tmux 里的 **Claude Code / Codex 多窗口**加一层轻量 HUD：

- **窗口名红绿灯** — 每个窗一眼看出 🟢在跑 / 🟡等你输入 / 🔴卡住需处理
- **底栏任务详情** — 当前窗仅显示 `resolve OAuth redirect loop`（真实标题）

配合多开 cc/codex 跑并行任务时，一眼看清哪个窗在忙、哪个在等你。

```
┌─ tmux tab ────────────────────────────────┐
│ 🟢 build-api   🟡 fix-login   🔴 run-tests │   ← 窗口名红绿灯（agent-watch 维护）
└────────────────────────────────────────────┘
 ...
 resolve OAuth redirect loop                   14:32   ← 底栏详情（agent-hud-title）
```

## 设计：去中心化自监听

每个 cc/codex 窗口**旁挂一个 `agent-watch`，只盯自己这一个 pane**：

- capture 自己 → 判红绿灯 → rename **自己**的窗
- 自己的窗口关闭 → watcher 自动退出；同一 pane 使用原子锁，始终只有一个 watcher

没有集中轮询器，所以：

| | 集中式轮询器 | tui-agent-hud（自监听） |
|---|---|---|
| 抢名冲突 | 轮询器 vs 子进程可能抢 | ✅ 每个只改自己的窗名，零冲突 |
| 生命周期 | 需管进程 + 防孤儿 | ✅ 绑自己的窗，窗关即退 |
| 跨 session | 需每 session 起一个 | ✅ 不存在——每个只认自己的 pane |
| cc / codex | — | ✅ 都兼容（自动识别） |

底栏详情由 tmux 内建 `status-right` 每 5s 渲染，无独立进程。红绿灯和任务编号只保留在窗口标签中，底栏不重复展示。

## 安装

### 一键安装（推荐）

复制下面整段执行。首次运行会克隆到 `~/tui-agent-hud`，重复运行会先以
`--ff-only` 更新，再重新执行幂等安装：

```bash
bash -c '
set -e
repo="https://github.com/langlanglanglanglang/tui-agent-hud.git"
install_dir="${TUI_AGENT_HUD_DIR:-$HOME/tui-agent-hud}"

if [ -d "$install_dir/.git" ]; then
  git -C "$install_dir" pull --ff-only
elif [ -e "$install_dir" ]; then
  echo "安装目录已存在且不是 Git 仓库：$install_dir" >&2
  exit 1
else
  git clone "$repo" "$install_dir"
fi

"$install_dir/install.sh"
'
```

安装完成后重开 shell，或按脚本最后的提示 `source` 当前 shell profile。
如需自定义安装目录，可在命令前设置 `TUI_AGENT_HUD_DIR=/path/to/tui-agent-hud`。

### 手动安装

```bash
git clone https://github.com/langlanglanglanglang/tui-agent-hud.git ~/tui-agent-hud
cd ~/tui-agent-hud
./install.sh
source ~/.zshrc     # 或重开 shell
```

`install.sh` 会（幂等，用块标记，可重复跑）：

1. 往 `~/.tmux.conf` 写底栏配置（`status-right` 调 `agent-hud-title` + `status-interval 5`）
2. 往 shell profile 写 `claude` / `codex` wrapper —— 启动时后台挂一个只盯本窗的 `agent-watch`
3. 往 `~/.tmux.conf` 写 tmux hook（新窗 / 切窗 / 聚焦时兜底挂 watcher）—— 覆盖 wrapper 之外的启动方式（IDE 插件、绝对路径等）；watcher 用原子锁保证每个 pane 只有一个实例，非 cc/codex 窗自退
4. 升级时清理旧 watcher，并自动为已经打开的 cc/codex pane 重新挂载监听

装完之后：**开 cc 或 codex → 自动挂 watcher（4s 刷红绿灯）+ tmux 自动刷底栏**，全程无需手动。

> 范围：**所有经 wrapper 启动的 cc/codex 窗**都刷红绿灯（不限窗名——`task-XXXX` 调度窗、`workflow` 等自命名窗都刷；纯 shell 窗不经 wrapper、不挂 watcher，自然不刷）。窗名 base 由你自己或调度层设定，agent-watch 只在前面加/换字形。

## 集成：接入真实任务标题

底栏标题三级回退：**标题缓存 → pane_title**。缓存是一个**约定目录**，任何调度层都可往里写：

```
$XDG_CACHE_HOME/tui-agent-hud/title/<base>.txt      # 内容 = 该任务的真实标题
# 例：echo 'resolve OAuth redirect loop' > ~/.cache/tui-agent-hud/title/fix-login.txt
```

写了缓存，底栏就显示真实标题；没写就回退 claude/codex 自己的 `pane_title`。这样项目本身不含任何业务逻辑，业务侧（如飞书任务系统）只需在起窗时写一个标题文件即可接入。

## 卸载

```bash
./uninstall.sh      # 撤 tmux 底栏 + wrapper，停所有 watcher
```

## 组成

| 文件 | 作用 |
|---|---|
| `bin/agent-watch` | 单窗自监听：盯自己 pane、刷自己窗名红绿灯、窗关自退 |
| `bin/agent-hud-title` | 底栏详情：仅标题（缓存→pane_title） |
| `bin/stop-agent-watchers` | 安装、升级、卸载时可靠停止 watcher（兼容旧版本） |
| `install.sh` / `uninstall.sh` | 幂等安装 / 卸载 |

## 依赖

`git` + `tmux` + `bash` + `awk` + `grep`。macOS / Linux 通用。

## 已知限制

- **状态判定基于 TUI 文案**：红绿灯靠匹配 CC/Codex 界面的运行标志（`esc to interrupt`）与确认菜单结构。上游若大改界面文案，判定可能需跟着更新——改 `bin/agent-watch` 的 `*_glyph` 函数即可，与其它部分解耦。
- **未命名窗重名**：没手动命名的 cc 窗，窗名默认取命令名（多个都显示 `🟡 claude`）。给窗起名即可区分（base 由你/调度层定，agent-watch 只加字形）。
- **自启覆盖面**：wrapper 覆盖命令行启动 + tmux hook 覆盖新窗/切窗；已开的旧 shell 需 `source` 一次，极特殊启动方式可手动 `agent-watch &`。
- **每窗一进程**：去中心化的取舍——N 个 cc 窗 = N 个 bash（实测每个 ~2MB、%CPU≈0、零 token）。要单进程可改集中式，但会牺牲「窗关自退 / 零抢名」的简洁。

## License

MIT
