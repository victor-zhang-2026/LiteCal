# Changelog

## 1.2.8 — 2026-11-11

- 新增/编辑表单和重复选择框加高，周视图收窄；月/周标题栏及年月、具体周选择器补悬停底色和完整文字提示。
- 日历、编辑窗与日期选择器支持深浅切换。深色月/周日期以灰阶区分过去和未来，今天以紫色圆标突出；未过期事项提亮。
- 悬浮球颜色保持固定。数据结构与日程存储不变；本轮界面及功能由用户在本机验收，发布时不新增自动化测试。

## 1.2.7 — 2026-11-11

- 月／周按钮支持按住拖动切换；直接点击时，浅灰毛玻璃选中块先滑动，再切换日历内容。
- 选中模式文字改为紫色，保留现有月历、纵向周历和日程存储。交互效果已由用户在本机确认；本次发布不新增自动化功能或界面测试。
- Drag or click the month/week control; the frosted selection slides before the calendar changes. Event data is unchanged.

## 1.2.6 — 2026-11-11

- 周视图改为周一至周日纵向七行，每行显示星期、公历与农历、当天全部事项；多事项自动扩高，超出屏幕时内部滚动。
- 统一月/周图标与事项颜色，优化今天、周末和无事项状态；修复周视图空白处双击新增。
- 月/周切换改为浮窗轻微收合或张开，旧画面渐退、新视图显现；修复切换过程中的布局越界闪退。
- 日程结构与存储不变。纵向周视图及最终切换效果已由用户在本机验收；本次仅做构建与发布包核验。
- Seven vertical day rows with all daily events, aligned colors, scrollable overflow, and a compact month/week transition. No event-data changes.

## 1.2.5 — 2026-11-09

- 在月、周视图原农历文字位置显示 7 个公历节日、9 个农历传统节日及二十四节气；节日优先于节气，同日只显示一个名称。
- 节气日期采用香港天文台 UTC+8 的 1901–2100 年逐年对照表；闰月不重复普通节日，除夕动态判断，不接入放假或调休数据。
- 显示逻辑完全离线，不写入日程 JSON；本次完成构建、签名及发布包核对，功能与界面测试由用户完成。
- Show Chinese holidays and all 24 solar terms in the existing lunar-date label, offline, with no event-data changes.

## 1.2.4 — 2026-11-05

- 周选择器持续以浅紫底色标出当前显示周，悬停时加深；保留今天的日期标记。
- Highlight the displayed week across its whole row in the week picker, with a stronger hover state.
- 本地 App 的视觉效果已由用户验收；本次未重新运行功能或界面测试。

## 1.2.3 — 2026-11-04

- 周视图支持点击标题按整周选择；标题显示年份，选择器仅高亮本月中的今天。
- 周视图事项字号与对应月份的月视图一致，调整周末明暗层次，并修正周/月视图相对悬浮球的定位。
- Week-row selection, year in the week title, matching event text size, refined weekend styling and consistent panel placement.
- 本次未运行功能或界面测试；仅完成构建与发布包核验。

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
