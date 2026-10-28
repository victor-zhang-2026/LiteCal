# LiteCal 1.2.0 — 固定重复日程

新增日程或编辑已有事项时，可以选择 **不重复、每天、每周、每月、每年**。仅提供固定频率，保持轻量。

- 月末和闰日自动适配目标月份，例如 1 月 31 日 → 2 月末 → 3 月 31 日。
- 跨日事项保留持续天数；月历和 +N 列表显示对应发生日期。
- 编辑、移动、删除作用于整组重复日程；改为不重复只保留首次事项。
- 旧数据自动备份后升级，原有事项默认不重复。旧版应用无法读取新格式，降级需恢复旧版备份。

Fixed daily, weekly, monthly and yearly recurrence, with month-end handling, whole-series actions and safe legacy migration. No custom intervals or per-occurrence exceptions.

**安装**：退出旧版，下载 `LiteCal-1.2.0-macOS-arm64.zip`，解压并替换应用程序中的 LiteCal。日程保存在应用包之外。

Apple silicon · macOS 13+ · 简体中文界面 · ad-hoc 签名，未经过 Apple 公证。

验证：12,304 项核心断言、310 项原生断言、Debug/Release 构建及隔离数据桌面操作检查通过。旧系统及物理多屏组合未全面复测。详见附件 `MANIFEST.md`；下载后可使用 `SHA256SUMS` 校验。
