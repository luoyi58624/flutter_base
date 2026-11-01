# ListTile

移动列表沿用原有的简单结构，由 `ElMobileTheme` 安装内部 `listTileBuilder` 与 `listTileGroupBuilder`，用户调用 ElListTile / ElListGroup。

- 行：ElView / Row，标题区 Expanded，上下 padding 16；无前侧内容时留 16，有内容时占 56。
- 组：RepaintBoundary / ElView / Column，卡片圆角 16、硬裁剪；标题在卡片外。
- 分隔线：继续使用 ElChildIndex 与 Stack / Positioned，非末行绘制 .5 线，正文起点对齐、右缩进 16；不改变布局高度。
- 内容：标题、说明、trailingText 由现有文本引擎或调用方 Widget 绘制，窄宽时自然换行。
- 图标：普通后缀按最近的 MaterialApp / CupertinoApp 选择右箭头，复用 ElFlutterUtil 的祖先查询；null 不保留尾部图标和间隔。

公共 ElModelValue 持有模型，Builder 读取和写入 currentValue。选择组直接使用子项 value，与组的单值或 List 模型比较，不给每行再绑定一份选择状态。单选通过 SDK RadioClient 将 ElView 的焦点交给官方 RadioGroup 导航，多选复制原 List 后更新，子项自身的事件、禁用、样式继续生效。

选择标记默认前置，组的 leading 为 false 时后置；选择行不显示导航箭头。开关末端是纯视觉轨道，由整行统一响应指针、Space 与辅助技术激活，避免一次操作切换两次。

弹窗按 Web 的 Popover 单选模式实现，复用 ElPortal，不另写浮层宿主。默认实际按压点锚定，键盘激活使用元素锚，显式 popupAnchor 优先；宽 236、圆角 17，先移动整组利用视口，再按实际内容限高滚动。打开后当前项聚焦并滚入可见，单选尾部使用 17px 勾选占位。

菜单独立处理上下方向键、Tab／Shift+Tab 循环、Home／End、500ms 字符前缀查找、Enter／Space 确认，禁用项跳过；全部禁用时保留面板焦点以响应关闭。ElListGroup 的 RadioGroup 导航不参与菜单。

ElMenuOption 在简单 label/value 上只增加 children、disabled、description、leading；仅叶子回写同一个泛型模型。移动端子层从原行位置展开，父层缩至 .94 并保留可点击返回区域，暂停父内容的焦点／语义／指针操作；返回保留父层滚动位置并恢复分支焦点。可用高度不足时整体上移，各层最多保留 36px 返回区域，极短视口的标题与当前层内容一同滚动。

展开从真实锚点缩放，时长 260ms、透明度 190ms；关闭时冻结各层位置和缩放，只整体淡出 200ms，立即停止交互并归还焦点，再通知模型。外点按下关闭整树，Escape／左方向键／系统返回逐层返回；点锚外部滚动关闭，菜单内部滚动不关闭。根菜单互斥，动态选项、禁用、快速重开和卸载均使用现有 Portal 生命周期清理。

默认颜色来自 context.elTheme，不增加独立主题对象。用户 style 最后合并，默认不提供鼠标悬停或键盘焦点环；减少动画设置会关闭默认过渡。
