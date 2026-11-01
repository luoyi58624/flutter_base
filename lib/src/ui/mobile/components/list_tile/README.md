# ListTile

移动列表沿用原有的简单结构，由 `ElMobileTheme` 安装内部 `listTileBuilder` 与 `listTileGroupBuilder`，用户调用 ElListTile / ElListTileGroup。

- 行：ElView / Row，标题区 Expanded，上下 padding 16；无前侧内容时留 16，有内容时占 56。
- 组：RepaintBoundary / ElView / Column，卡片圆角 16、硬裁剪；标题在卡片外。
- 分隔线：继续使用 ElChildIndex 与 Stack / Positioned，非末行绘制 .5 线，正文起点对齐、右缩进 16；不改变布局高度。
- 内容：标题、说明、trailingText 由现有文本引擎或调用方 Widget 绘制，窄宽时自然换行。
- 图标：普通后缀按最近的 MaterialApp / CupertinoApp 选择右箭头，复用 ElFlutterUtil 的祖先查询；null 不保留尾部图标和间隔。

公共 ElModelValue 持有模型，Builder 读取和写入 currentValue。选择组直接使用子项 value，与组的单值或 List 模型比较，不给每行再绑定一份选择状态。单选通过 SDK RadioClient 将 ElView 的焦点交给官方 RadioGroup 导航，多选复制原 List 后更新，子项自身的事件、禁用、样式继续生效。

选择标记默认前置，组的 leading 为 false 时后置；选择行不显示导航箭头。开关末端是纯视觉轨道，由整行统一响应指针、Space 与辅助技术激活，避免一次操作切换两次。

点击弹窗复用 ElPortal，面板直接跟随当前选项和模型重建；保留 popupAnchor、popupMaxHeight、popupStyle、optionStyle 与 closeOnSelect。关闭行为和焦点恢复由已有弹层处理，不另写浮层机制。

默认颜色来自 context.elTheme，不增加独立主题对象。用户 style 最后合并，默认不提供鼠标悬停或键盘焦点环；减少动画设置会关闭默认过渡。
