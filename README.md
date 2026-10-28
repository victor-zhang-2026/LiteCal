# LiteCal

**A calendar, one hover away.**

鼠标移到屏幕边缘，一眼看清整月安排。原生 macOS 悬浮日历，本地保存、无需账号、离线可用。

A native floating month calendar for macOS. Hover to see your month, capture a plan, and return to work. Local storage, no account, fully offline.

[下载 / Download 1.2.0](https://github.com/victor-zhang-2026/LiteCal/releases/download/v1.2.0/LiteCal-1.2.0-macOS-arm64.zip) · [发布说明 / Release notes](https://github.com/victor-zhang-2026/LiteCal/releases/tag/v1.2.0) · [反馈 / Issues](https://github.com/victor-zhang-2026/LiteCal/issues)

![LiteCal 整月日历，使用虚构演示事项](docs/images/calendar.png)

## 功能 / Features

- **随时查看**：移入悬浮球展开；预览时移出收起。点击月历后保持打开，点击外部再收起。
- **整月安排**：周一至周日、公历与农历；每个日期直接显示三行事项，更多显示 `+N`。
- **快速记录**：双击空白日期新增，或拖过几天创建连续事项；单击已有事项编辑，右键编辑或确认删除。
- **固定重复**：不重复、每天、每周、每月、每年；新增与编辑使用同一组选项。
- **连续多日**：横条跨日期显示，跨周分段；拖动整段平移，持续天数保持不变。
- **轻松定位**：左右方向键切月；点击年月跳转年份和月份；「今天」返回当前月。
- **自然聚焦**：已结束事项自动变浅，今天与未来事项保持清晰；历史事项仍可操作。
- **本地离线**：无账号、服务器、同步、广告、遥测或系统日历读取。

Hover to open; click to keep the calendar visible until you click elsewhere. Read three event rows per date, open overflow with `+N`, and see Gregorian and Chinese lunar dates. Double-click to create, drag across dates for a range, edit by clicking, and move an event while keeping its duration. Arrow keys and the month picker make navigation quick. Past events fade automatically. Repeat events daily, weekly, monthly or yearly with a single selection.

**Current UI: Simplified Chinese.** English product documentation does not imply an English interface. This release is for Apple silicon Macs; there is no Windows or Intel binary.

## 安装 / Install

1. 下载上方的 `LiteCal-1.2.0-macOS-arm64.zip`，解压并将 `LiteCal.app` 拖入「应用程序」。GitHub 的 `Source code` 为源码，不是安装包。
2. 如已有 LiteCal 在运行，先右键悬浮球退出，再打开新版。日程文件会继续保留。
3. 当前版本使用 ad-hoc 本地签名，未经过 Developer ID 签名或 Apple 公证。确认来自本仓库并核对 Release 的 `SHA256SUMS` 后，如被系统拦截，按 [Apple 安装说明](https://support.apple.com/en-us/102445)在「系统设置 → 隐私与安全性」中选择「仍要打开」。

Download the app ZIP, unzip it, and move LiteCal to Applications. Quit the old instance before launching an update. The build is ad-hoc signed and not notarized; verify its source and checksum before following Apple's Open Anyway instructions.

部署目标 macOS 13+；本轮测试环境为 Apple silicon / macOS 27.0.1。旧系统、物理多屏及不同缩放组合未全部实测。详见 [安装与数据指南](docs/install-and-data.md)。

Deployment target: macOS 13+. Tested on Apple silicon / macOS 27.0.1. Older systems and physical multi-display/scaling combinations have not all been tested.

## 使用 / Use

| 操作 | 结果 |
| --- | --- |
| 鼠标移入悬浮球 | 展开整月日历 |
| 点击月历 / 点击外部 | 保持展开 / 收起；编辑草稿受保护 |
| 双击空白日期 / 拖选日期范围 | 新增单日 / 多日事项 |
| 单击事项 / 右键事项 | 编辑 / 编辑或确认删除 |
| 拖动事项 | 移动日期，多日事项保持持续天数 |
| 选择重复频率 | 不重复、每天、每周、每月、每年 |
| 点击起止日期 | 紧凑日期网格；点选对应端点或拖选整段范围 |
| ← / →、点击年月、「今天」 | 切月、快速跳转、回到当前月 |
| Enter / Esc | 保存 / 取消当前选择或编辑 |
| 右键悬浮球、⌘Q | 退出确认；标题栏 × 只收起 |

拖选与拖动范围为当前网格可见日期；更远的日期通过编辑器翻月选择。当前版本聚焦按日安排，不含时间段、提醒、自定义重复、分类、同步或第三方日历连接。

Drag targets must be visible in the current grid. Use the date fields to reach other months. LiteCal currently focuses on day-based plans, without times, reminders, custom repeat rules, categories, sync, or external calendar integration.

重复从开始日期起持续生效，每周固定相隔七天。每月按开始日的日号、每年按开始日的月日重复；目标月份没有对应日期时使用月末，之后仍按最初日期计算。例如 1 月 31 日按月重复会落在 2 月末、3 月 31 日。跨日事项保留持续天数。

编辑和删除作用于整组；拖动按相同天数移动整组的首次起止日，再按频率重新计算（月末结果可能随新起始日改变）。改为「不重复」后只保留首次事项。当前仅提供这四种固定频率，持续重复；没有自定义间隔、结束次数或单次例外。

Repeats start at the original start date. Monthly/yearly repeats clamp to the last day when needed, without drifting the original anchor. Edit/delete affect the entire series. Dragging shifts the original range by the day delta, then recalculates the series. Choosing no repeat keeps only the original event. No custom intervals, end conditions, or single-occurrence exceptions are provided.

## 数据 / Data

日程及备份位于 `~/Library/Application Support/LiteCal/`，主文件为 `events.json`。日期使用 `YYYY-MM-DD` 的日历日语义；旧数据在保留原始备份后自动升级到 schema 3；原有事项默认不重复。应用替换不会删除日程。

Events and backups live in `~/Library/Application Support/LiteCal/`. Storage is local, unencrypted JSON. There is no automatic cloud backup. See [Data and privacy](docs/privacy.md).

## 从源码构建 / Build

需要 Swift 6 工具链与兼容 macOS SDK，无第三方依赖。

```sh
git clone https://github.com/victor-zhang-2026/LiteCal.git
cd LiteCal
export LITECAL_MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path)"
./scripts/build-app.sh release
open build/LiteCal.app
```

If several SDKs are installed, set `LITECAL_MACOS_SDK` to one compatible with your Swift toolchain. The published build used Swift 6.4 and the macOS 26.5 SDK.

```sh
./scripts/test.sh
./scripts/test-native.sh
```

Core tests cover civil dates, lunar dates, persistence/migration and layout. Native tests show temporary windows and use isolated test data. The release passed 12,304 core assertions and 310 native assertions; these do not replace physical multi-monitor or manual interaction testing. See [release validation](release/v1.2.0/MANIFEST.md).

```text
Sources/LiteCal/  App lifecycle, floating panels, calendar, editor and storage
Resources/       App identity and icons
Tests/           Core and native tests
scripts/         Build, tests and isolated demo capture
release/         Versioned release notes and checksums
```

## 共创 / Contributing

LiteCal 延续 Lite 系列的小工具方向：[LiteTick](https://github.com/victor-zhang-2026/LiteTick) 用于待办，[LitePark](https://github.com/victor-zhang-2026/LitePark) 用于稍后回看的 ChatGPT 对话，LiteCal 用于按日期查看安排。

Built iteratively with Codex, with product scope and interaction decisions guided by real feedback. Bug reports and small, focused contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) — Copyright (c) 2026 Victor Zhang.
