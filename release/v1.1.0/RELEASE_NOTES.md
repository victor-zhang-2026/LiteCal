# LiteCal 1.1.0 — A calendar, one hover away.

鼠标移到屏幕边缘，一眼看清整月安排。

LiteCal 的首个公开版本。原生 macOS、本地离线、免费开源。

![LiteCal](https://raw.githubusercontent.com/victor-zhang-2026/LiteCal/main/docs/images/launch.png)

## 下载 / Download

**Apple 芯片 Mac：下载下方 `LiteCal-1.1.0-macOS-arm64.zip`。** 解压并拖入「应用程序」。GitHub 自动提供的 Source code 为源码。

Current interface: **Simplified Chinese**. Apple silicon binary; macOS 13+ deployment target. Tested on macOS 27.0.1; older systems and physical multi-display/scaling combinations have not all been tested.

## 这一版能做什么

- 移入悬浮球展开整月日历；点击后保持打开，点击外部收起。
- 每天直接显示三行事项，更多通过 `+N` 查看；包含农历。
- 双击新增，拖选多天创建连续事项；紧凑浮层编辑名称与日期。
- 多日事项连续条状展示，跨周分段；拖动改期时保留持续天数。
- 点击年月快速跳转，左右键切月，「今天」返回当前月份。
- 结束日期早于今天的事项自动变浅。
- 右键事项编辑/确认删除；右键悬浮球退出。
- JSON 本地持久化，原子写入与旧数据迁移备份，无需账号或联网。

## Features

Hover to read your month. Click to keep it open. Double-click to capture a plan, drag across dates for a multi-day event, and move the whole event without changing its duration. Event names appear directly in each date, with overflow, lunar dates, quick month navigation and automatic fading of past events.

Native Swift/AppKit, offline use, local JSON storage and MIT licensing. Day-based plans only: no reminders, recurrence, time slots, sync or external calendar connection.

## 安装与数据 / Install and data

- 如已有测试版运行，先从悬浮球右键菜单退出，再替换 App。已保存日程会继续保留。
- 数据和备份位于 `~/Library/Application Support/LiteCal/`，是未加密的本地 JSON。旧单日数据自动迁移前会保留原始备份。
- 此包为 ad-hoc 签名，尚未经过 Apple Developer ID 签名和公证。确认下载来源并核对 SHA-256 后，按照[安装指南](https://github.com/victor-zhang-2026/LiteCal/blob/main/docs/install-and-data.md)完成首次打开。

Quit the old instance before replacing the app. Existing events are retained. The app is ad-hoc signed and not notarized; verify the download and follow the install guide.

## 验证 / Validation

11,766 core assertions and 276 native assertions passed. See the attached `MANIFEST.md` for coverage and untested physical-device scenarios. The accepted build 4 binary is unchanged.

## SHA-256

```text
410e95272d7231b8eb53f3f012ceca87865c8dd7bcccb291b552e92ebb083a53  LiteCal-1.1.0-macOS-arm64.zip
```

欢迎在 [Issues](https://github.com/victor-zhang-2026/LiteCal/issues) 提交实际使用反馈。演示截图均使用虚构日程。
