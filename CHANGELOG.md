# Changelog

## 1.2.2 — 2026-10-29

- 修复合盖、外接屏及屏幕布局切换后的悬浮球错位，按显示器保存相对位置。
- 悬浮球层级与 LiteTick、LitePark 对齐，拖动经过 Dock 时保持可见。
- Preserve display-relative floating-ball positions across clamshell and monitor-layout changes. Keep the floating ball above the Dock.

## 1.2.1 — 2026-10-29

- 新增紧凑七列周视图及「月 / 周」切换，记忆上次选择，按事项数量自适应高度。
- 选中背景、日期格与窗口高度使用 0.23 秒原生过渡，窗口顶部及宽度保持稳定。
- 支持上一周 / 下一周、今天、跨年日期范围及月周日期衔接。
- 复用原有日程操作和跨日布局；按目标视图重算截断、延续、占用行，保持原始数据及 schema 3。
- 月历网格四种尺寸与原版逐像素一致；16,690 核心、310 原有原生、716 周专项断言和实际桌面操作通过。
- Compact week view with animated month/week switching, adaptive height, view persistence and shared event interactions. No data-format changes.

## 1.2.0 — 2026-10-28

- 新增固定重复：不重复、每天、每周、每月、每年；新增和编辑共用。
- 月末与闰日按目标月份最后一天兼容，后续仍沿用原始日期；跨日事项保留天数。
- 重复事项支持整组编辑、移动和确认删除；月历、历史弱化与溢出列表显示对应发生日期。
- schema 1/2 安全备份后升级为 schema 3，原有事项默认不重复。
- Daily, weekly, monthly and yearly recurrence; whole-series actions; safe legacy migration. No custom repeat intervals or exceptions.
- Validated with 12,304 core assertions, 310 native assertions, Debug/Release builds and isolated desktop create/next-month/edit checks.

## 1.1.0 — 2026-10-22

First public release, based on accepted local build 4.

- Native floating month calendar with hover preview and click-to-keep behavior.
- Day-based events, compact shared editor and drag-select date ranges.
- Continuous multi-day bars, weekly segmentation, three visible rows and overflow.
- Move events by dragging; edit or confirm deletion from the context menu.
- Chinese lunar dates, quick year/month navigation, arrow keys and Today.
- Past-event fading based on the end date; midnight and wake refresh.
- Local JSON persistence, atomic updates and safe legacy-data migration.
- Simplified Chinese UI, Apple silicon package, ad-hoc signature.

本次为首个公开版本；本地 V1.0 和 V1.1 测试迭代未曾作为 GitHub 正式版本发布。
