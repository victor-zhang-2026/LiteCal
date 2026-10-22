# Contributing

欢迎通过 Issue 提交问题或小范围改进。Please keep changes focused on a lightweight, offline, day-based calendar.

提交问题时请提供版本、macOS 版本、芯片类型、屏幕数量/缩放、复现步骤和预期结果。截图请使用演示事项或遮去私人信息，不要上传真实 events.json。

For a bug report, include the app version, macOS version, chip type, display setup, steps, expected behavior and actual result. Use fictional events in screenshots; do not upload your personal event database.

PR 请说明用户可感知的变化及实际验证。测试使用独立目录，并明确哪些真实鼠标、多屏或旧系统场景未测试。Keep dependency-free native AppKit, civil-date storage, atomic writes and migration backups intact. Discuss major scope changes in an issue before implementation.
