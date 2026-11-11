# LiteCal 1.2.6

- 周视图改为周一至周日纵向七行，以「星期｜公历与农历｜事项」展示每天的安排。多个事项逐行显示，行高自适应，内容过高时在周视图内部滚动。
- 对齐月视图的图标、事项颜色与周末配色，优化今天高亮、日期和农历排版；修复无事项区域双击新增。
- 月／周切换时浮窗轻微收合或张开，原视图画面逐渐过渡到目标视图；修复切换过程中的数组越界闪退。
- 月视图布局、事项数据结构和存储方式保持不变。

The week view now uses seven vertical day rows with all events visible. The month/week transition gently resizes the panel and blends the two views. Event data is unchanged.

Apple silicon / macOS 13+. Includes the app ZIP, SHA-256 checksum and release manifest. Ad-hoc signed, not notarized.

纵向周视图及最终切换效果已由用户在本机验收。本次发布另完成构建、签名和发布包核验；未新增自动化功能或界面测试。
