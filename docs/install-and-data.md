# 安装与数据 / Install and data

## 安装

从 [v1.2.1 Release](https://github.com/victor-zhang-2026/LiteCal/releases/tag/v1.2.1) 下载 `LiteCal-1.2.1-macOS-arm64.zip`，解压，将 App 拖入「应用程序」。macOS 13+ 部署目标，Apple silicon；实际测试环境 macOS 27.0.1。当前界面为简体中文。

发布包采用 ad-hoc 本地签名，尚未 Developer ID 签名/公证。如系统阻止打开，先确认来自本仓库并核对 SHA-256，然后按 [Apple 官方指南](https://support.apple.com/en-us/102445)使用「系统设置 → 隐私与安全性 → 仍要打开」。无需关闭系统安全保护。

Download the app ZIP from the Release, unzip, and move LiteCal to Applications. This build is ad-hoc signed and not notarized. Verify the download and checksum, then follow Apple's Open Anyway instructions if necessary.

## 校验

在 ZIP 所在目录运行以下命令，并与同一 Release 的 `SHA256SUMS` 对照：

```sh
shasum -a 256 LiteCal-1.2.1-macOS-arm64.zip
```

## 升级

先右键悬浮球退出，再替换 App。数据保存在应用包之外，不会因为替换 App 而删除。不要同时打开两个使用相同数据目录的实例。

1.2.0 → 1.2.1 沿用 schema 3，无新增数据迁移；「月 / 周」选择保存在用户偏好中，首次默认月视图。

Quit the existing instance before replacing the app. Data is outside the app bundle and remains in place.

## 数据位置与备份

Finder → 前往 → 前往文件夹：`~/Library/Application Support/LiteCal/`。

- `events.json`：当前事项，schema 3，起止日期保存为 `YYYY-MM-DD`。
- `events.backup.json`：上次有效数据的备份。
- `events.schema1.backup.json`：首次迁移旧数据前的原始备份；存在不同来源时保留额外 UUID 备份，不覆盖。
- `events.schema2.backup.json`：从 1.1 升级到重复日程版本前的原始备份，同样不会覆盖不同来源。
- 悬浮位置偏好：`~/Library/Preferences/app.litecal.mac.plist`。

迁移保留 ID、名称、创建与更新时间；旧单日字段转为相同的开始、结束日期。原有事项默认「不重复」；重复日程保存一条规则，按查看范围生成显示。失败或未知版本停止写入。V1.1 及更早版本无法读取 schema 3；降级需先备份整个数据目录并恢复对应旧版备份，备份之后的修改不会随之保留。

For recovery, quit LiteCal and copy the whole data directory somewhere safe first. Replace `events.json` with the desired valid backup and reopen. A backup restores its own point in time; it does not merge later changes.

## 卸载

退出并移除 App 即可停止使用。日程目录会保留。只有在确认不再需要数据并做好备份后，才手动移除上述数据目录与偏好文件。

Removing the app leaves event files intact. Delete the data directory and preferences only if you also intend to remove your saved plans.
