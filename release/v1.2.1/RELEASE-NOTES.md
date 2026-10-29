# LiteCal 1.2.1 — 紧凑周视图

顶部新增 **月 / 周** 切换，查看本周安排时保持紧凑，随时返回原有月历。

- 周一至周日横向七列，显示公历、农历、今天高亮与事项条；按事项数量自适应高度，更多事项沿用 +N 完整列表。
- 选中背景、日期格和窗口高度使用约 0.23 秒原生动画，窗口顶部及宽度保持稳定，记住上次选择的视图。
- 左右箭头按当前模式切月或切周；今天返回当前月或今天所在周；跨年周范围显示两端年份。
- 月周切换优先沿用选中日期；跨日事项按当前可见周重新截断和排列，保留延续标记。
- 复用原有新增、编辑、右键删除、拖动、固定重复与历史弱化逻辑。月历原有日期网格保持不变，日程格式继续使用 schema 3。

Compact seven-column week view with animated month/week switching, adaptive height, view persistence, week navigation and shared event interactions. Cross-day bars are recalculated for the visible week. Existing month layout and event storage are preserved.

**安装**：退出旧版，下载 `LiteCal-1.2.1-macOS-arm64.zip`，解压并替换应用程序中的 LiteCal。1.2.0 升级到 1.2.1 无新增数据迁移，原有日程继续保留。

Apple silicon · macOS 13+ · 简体中文界面 · ad-hoc 签名，未经过 Apple 公证。

验证：16,690 核心断言、310 既有原生断言、716 周专项断言通过；实际鼠标新增/编辑/删除、单日与跨日拖动、连续切换和真实进程重启恢复通过。30 次原生动画采样确认顶部/宽度稳定及各组件的中间状态。物理多屏、不同缩放、旧系统及视频帧率未全量验证。

下载后请使用附件 `SHA256SUMS` 校验；版本、签名与测试边界详见 `MANIFEST.md`。
