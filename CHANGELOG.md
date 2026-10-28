# Changelog

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
