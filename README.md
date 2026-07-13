# cc-window-hud

给 tmux 里的 **Claude Code / Codex 多窗口**加一层轻量 HUD：

- **窗口名红绿灯** — 每个窗一眼看出 🟢在跑 / 🟡等你输入 / 🔴卡住需处理
- **底栏任务概览** — 当前窗显示 `🟡 task-1332 · 后台开单时缺少线索渠道和线索人`（红绿灯 + 编号 + 真实标题）

配合多开 cc/codex 跑并行任务时，一眼看清哪个窗在忙、哪个在等你。

```
┌─ tmux tab ────────────────────────────────┐
│ 🟢 task-0379   🟡 task-1332   🔴 task-1401 │   ← 窗口名红绿灯（cc-watch 维护）
└────────────────────────────────────────────┘
 ...
 🟡 task-1332 · 后台开单时缺少线索渠道和线索人   14:32   ← 底栏概览（cc-hud-title）
```

## 设计：去中心化自监听

每个 cc/codex 窗口**旁挂一个 `cc-watch`，只盯自己这一个 pane**：

- capture 自己 → 判红绿灯 → rename **自己**的窗
- 自己的窗口关闭 → watcher 自动退出（无孤儿）

没有集中轮询器，所以：

| | 集中式轮询器 | cc-window-hud（自监听） |
|---|---|---|
| 抢名冲突 | 轮询器 vs 子进程可能抢 | ✅ 每个只改自己的窗名，零冲突 |
| 生命周期 | 需管进程 + 防孤儿 | ✅ 绑自己的窗，窗关即退 |
| 跨 session | 需每 session 起一个 | ✅ 不存在——每个只认自己的 pane |
| cc / codex | — | ✅ 都兼容（自动识别） |

底栏概览由 tmux 内建 `status-right` 每 5s 渲染，无独立进程。

## 安装

```bash
git clone <repo> ~/WorkSpace/cc-window-hud
cd ~/WorkSpace/cc-window-hud
./install.sh
source ~/.zshrc     # 或重开 shell
```

`install.sh` 会（幂等，用块标记，可重复跑）：

1. 往 `~/.tmux.conf` 写底栏配置（`status-right` 调 `cc-hud-title` + `status-interval 5`）
2. 往 shell profile 写 `claude` / `codex` wrapper —— 启动时后台挂一个只盯本窗的 `cc-watch`

装完之后：**开 cc 或 codex → 自动挂 watcher（4s 刷红绿灯）+ tmux 自动刷底栏**，全程无需手动。

> 前提：窗口名需是 `task-XXXX` / `epic-task-XXXX` 才刷红绿灯（普通 shell / 看板窗不碰）。命名由你的调度层负责（见「集成」）。

## 集成：接入真实任务标题

底栏标题三级回退：**标题缓存 → pane_title**。缓存是一个**约定目录**，任何调度层都可往里写：

```
$XDG_CACHE_HOME/cc-window-hud/title/<base>.txt      # 内容 = 该任务的真实标题
# 例：echo '后台开单时缺少线索渠道和线索人' > ~/.cache/cc-window-hud/title/task-1332.txt
```

写了缓存，底栏就显示真实标题；没写就回退 claude/codex 自己的 `pane_title`。这样项目本身不含任何业务逻辑，业务侧（如飞书任务系统）只需在起窗时写一个标题文件即可接入。

## 卸载

```bash
./uninstall.sh      # 撤 tmux 底栏 + wrapper，停所有 watcher
```

## 组成

| 文件 | 作用 |
|---|---|
| `bin/cc-watch` | 单窗自监听：盯自己 pane、刷自己窗名红绿灯、窗关自退 |
| `bin/cc-hud-title` | 底栏概览：红绿灯 + 编号 + 标题（缓存→pane_title） |
| `install.sh` / `uninstall.sh` | 幂等安装 / 卸载 |

## 依赖

`tmux` + `bash` + `awk` + `grep`。macOS / Linux 通用。

## License

MIT
