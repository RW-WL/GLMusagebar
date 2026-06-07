# GLM Usage Monitor

[English](#english) | [中文](#中文)

---

<a id="english"></a>

## A macOS menu bar app for monitoring GLM Coding Plan usage

Displays 5h/7d watermarks, model distribution, and MCP usage at a glance. Built with Swift + AppKit, zero dependencies.

<img width="360" alt="GLM Usage Monitor" src="https://img.shields.io/badge/platform-macOS%2014%2B-blue">

### Features

- **Real-time watermarks** — 5h and 7d usage percentages in the menu bar, turns red when >80%
- **Model breakdown** — 24h token usage and call count per model
- **MCP tracking** — Monthly MCP usage with per-tool details
- **Auto-refresh** — Updates every 30 minutes
- **Manual refresh** — Press `⌘R` or click Refresh
- **Lightweight** — ~180KB, no Dock icon, menu bar only

### Screenshot

```
┌─────────────────────────────────┐
│ 🔬 GLM Usage Monitor           │
│─────────────────────────────────│
│ 水位                            │
│   5h   ████░░░░░░  4%          │
│   7d   ████████░░  65%         │
│─────────────────────────────────│
│ 24h 用量  ·  1,063 次调用       │
│   5.1       65.8M  80.3%       │
│   4.5-Air   16.0M  19.5%       │
│─────────────────────────────────│
│ MCP (本月)  870/4,000  21.8%   │
│─────────────────────────────────│
│ 🔄 刷新                        │
│ 退出                            │
└─────────────────────────────────┘
```

### Requirements

- macOS 14.0+
- Swift Command Line Tools (`xcode-select --install`)
- GLM Coding Plan with API key configured in `~/.openclaw/openclaw.json`

### Build

```bash
git clone https://github.com/RW-WL/GLMusagebar.git
cd GLMusagebar
bash build.sh
```

The built app will be at `build/GLMUsageBar.app`.

### Install

```bash
cp -R build/GLMUsageBar.app /Applications/
```

To auto-start on login, add **GLMUsageBar** to System Settings → General → Login Items.

### Configuration

The app reads your ZHIPU API key from:

```
~/.openclaw/openclaw.json → models.providers.zhipu.apiKey
```

### Project Structure

```
Sources/
├── main.swift          # AppDelegate + status bar UI
├── Models.swift        # Data models
└── UsageService.swift  # ZHIPU API client
Resources/
└── Info.plist          # LSUIElement=true (no Dock icon)
build.sh                # Build script (swiftc, no Xcode needed)
Makefile                # build / run / clean / install
```

### License

MIT

---

<a id="中文"></a>

## GLM 用量监控 — macOS 菜单栏应用

在菜单栏实时显示 GLM Coding Plan 的 5h/7d 水位、模型用量分布和 MCP 使用情况。纯 Swift + AppKit，零依赖。

### 功能

- **实时水位** — 菜单栏常驻显示 5h 和 7d 用量百分比，超过 80% 变红
- **模型分布** — 24h 内各模型 Token 用量及调用次数
- **MCP 追踪** — 本月 MCP 使用量及各工具明细
- **自动刷新** — 每 30 分钟自动更新
- **手动刷新** — 快捷键 `⌘R` 或点击刷新按钮
- **轻量** — 约 180KB，无 Dock 图标，仅菜单栏

### 环境要求

- macOS 14.0+
- Swift 命令行工具（`xcode-select --install`）
- GLM Coding Plan，API Key 配置在 `~/.openclaw/openclaw.json`

### 编译

```bash
git clone https://github.com/RW-WL/GLMusagebar.git
cd GLMusagebar
bash build.sh
```

编译产物在 `build/GLMUsageBar.app`。

### 安装

```bash
cp -R build/GLMUsageBar.app /Applications/
```

如需开机自启，在系统设置 → 通用 → 登录项中添加 **GLMUsageBar**。

### 配置

应用从以下路径读取 ZHIPU API Key：

```
~/.openclaw/openclaw.json → models.providers.zhipu.apiKey
```

### 项目结构

```
Sources/
├── main.swift          # AppDelegate + 菜单栏 UI
├── Models.swift        # 数据模型
└── UsageService.swift  # ZHIPU API 客户端
Resources/
└── Info.plist          # LSUIElement=true（无 Dock 图标）
build.sh                # 编译脚本（swiftc，无需 Xcode）
Makefile                # build / run / clean / install
```

### 许可证

MIT
