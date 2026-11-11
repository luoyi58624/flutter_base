# ElView

盒模型、文本、样式、事件和语义的基础宿主。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 内容与盒模型

```dart
ElView(
  style: ElStyle(
    width: '100%',
    padding: EdgeInsets.all(12),
    margin: EdgeInsets.only(bottom: 8),
    backgroundColor: Colors.blue,
    borderRadius: BorderRadius.circular(8),
    color: Colors.white,
    fontSize: 16,
  ),
  child: ['状态：', TextSpan(text: '已保存', style: TextStyle(fontWeight: FontWeight.bold))],
);
```

`child` 为 Widget 时直接承载；Iterable 作为行内混排；其他值作为文本。多行布局请显式用 Column/List，不能把内容数组当成纵向布局。Expanded / Flexible / Spacer 放在 Flex 的直接槽内，Positioned 放在 Stack 的直接槽内，不能直接作为 ElView.child。

### 动态文本

将 `ValueListenable` 直接作为 `child`，ElView 会显示它的当前值并管理订阅：

```dart
final title = ValueNotifier<String>('原来的标题');
final view = ElView(
  style: ElStyle(fontSize: 16),
  child: title,
);

// view 可以保持同一个实例；换字直接更新现有渲染对象。
title.value = '更新后的标题';
```

字符串、数字等普通值之间的通知直接调用现有文本更新入口，不触发
`ViewElement.update`、`performRebuild` 或 `updateRenderObject`；
内容相等时沿用既有排版缓存。文字改变仍按需进行布局、绘制和语义更新。

值为 Widget、Iterable 或 InlineSpan 时，沿用原有内容分派并在构建阶段协调子树，
因此包含 WidgetSpan 的富文本也能正确挂载和移除。独立 IconData 保持不随文字缩放，
在图标与普通文字之间切换时会重新同步环境参数。这些结构或类别切换不承诺跳过构建。

替换来源会移除旧监听并立即读取新值；临时移出树时暂停监听，重新挂载时读取最新值，
卸载时移除监听。ElView 不销毁外部来源，调用方在不再使用时负责 `dispose()`。
只订阅顶层 `child`，不会递归订阅 Iterable 或其他载荷中的 notifier。

### 高级文本配置

低频字体和段落参数统一放在 `ElStyle.textOptions`：

```dart
ElView(
  style: ElStyle(
    fontSize: 16,
    textOptions: ElTextOptions(
      locale: Locale('zh', 'CN'),
      strutStyle: StrutStyle(fontSize: 16),
      textWidthBasis: TextWidthBasis.longestLine,
    ),
  ),
  child: '高级排版配置',
);
```

`ElTextOptions` 收纳 `locale`、`textScaler`、`strutStyle`、`textWidthBasis`、`textHeightBehavior`、
`leadingDistribution`、`textBaseline`。所有属性只影响当前文本，不向后代继承；未声明的值由文本引擎
在消费时补齐。字体轴、字体回退、字体特性和单词间距保留在 ElStyle，沿用原来的继承和变体规则。

这组配置只允许放在基础样式。状态、断点、`onSelection`、`starting` 和关键帧中的 `textOptions`
会被拒绝，也不属于 `ElTransitionField`。常用的颜色、字号、字重、行高、字距等仍支持变体和过渡。
`ElText` 保留 Flutter `Text` 的参数形式，内部统一转换到这组配置。

文本引擎按实际内容启用，管理自己的排版、字体监听、选区与内联子树。纯 Widget 或空内容不会创建
文本引擎或订阅文本环境；文本切回这些内容时会移除环境绑定并释放资源。仅声明可继承的文本样式也
不会让纯容器启用文本引擎。


| ElStyle 字段 | 用途 |
| --- | --- |
| width / height、minWidth / maxWidth、minHeight / maxHeight | 尺寸和约束，尺寸支持数字、百分比及 ElDimension |
| padding / margin / alignment / aspectRatio | 内外间距、内容对齐、宽高比 |
| backgroundColor / gradient / backgroundImage / border / borderRadius / boxShadow | 背景、边框、圆角与阴影 |
| color / fontSize / fontWeight / fontFamily / lineHeight | 文本样式；可继承字段沿 ElView 链传递 |
| maxLines / textOverflow / softWrap / textAlign | 文本行数、溢出、换行和对齐 |
| iconSize / iconColor、cursor / pointerEvents / userSelect | 图标、光标、命中与文本选择 |
| opacity / transform / transformOrigin / clipBehavior | 透明度、变换、变换原点与裁剪 |
| filter / backdropFilter / outline / clipPath | 滤镜、背景滤镜、外轮廓与自定义裁剪 |

`style.merge(other)` 用后者的非空字段覆盖前者。clipPath 与 borderRadius 不应同时声明。

## 分层阴影

```dart
ElStyle(
  backgroundColor: Colors.white,
  borderRadius: BorderRadius.circular(16),
).withShadow(type: .uniform, level: .md, strength: 0.8);
```

`ElShadowType` 提供 material、uniform、floating、contact、glow、inset 六种风格，
使用 xs、sm、md、lg、xl 五级参数。Material 以 Flutter 官方三层投影为基础，其他风格调整
方向、范围和浓度；不依赖 MaterialApp、应用主题或品牌 token。

不传 color 时按当前最终生效的 backgroundColor 自适应配色；没有背景或背景完全透明时
使用黑色。显式传 `color: null` 固定为传统黑色，传入 Color 则保留指定色值，颜色透明度
与预设浓度、strength 相乘。自适应只读取当前纯色背景，不查询祖先或分析图片、渐变。

blurRadius 覆盖最宽阴影层的模糊半径，其余层按比例缩放；offset 与 spreadRadius
追加整体偏移和扩散。strength、blurRadius 允许为零，强度与模糊不能为负，所有数值必须有限。
扩展只替换当前 boxShadow，保留其余属性和变体，可继续声明 boxShadow 过渡。

阴影绘制跟随实际尺寸和最终圆角，扩散采用 W3C 的小圆角连续修正规则；内阴影裁剪在盒内。
背景与圆角变体、动画由现有样式引擎驱动，不需要额外 Widget 或控制器。

## 交互状态与主题

```dart
ElView(
  style: ElStyle(
    padding: EdgeInsets.all(12),
    backgroundColor: Colors.blue,
    onHover: ElStyle(backgroundColor: Colors.indigo),
    onTap: ElStyle(opacity: 0.7),
    onFocusVisible: ElStyle(backgroundColor: Colors.deepPurple),
    onDisabled: ElStyle(opacity: 0.4),
    onDark: ElStyle(backgroundColor: Colors.blueGrey),
  ),
  event: ElEvent(onTap: (_) {}),
  child: '交互区域',
);
```

状态变体还包括 onFocus、onFocusWithin、onSelection。onTap 是按压样式，点击回调写在 event.onTap。禁用由 `ElEvent(disabled: true)` 声明；切换按钮的已选外观由调用方状态决定，不要将 selected 语义当作样式开关。

启用焦点后，拥有主焦点的 ElView 会在 Enter、小键盘 Enter 或空格按下时自动进入 onTap，按键释放后退出；Esc、失焦、禁用和卸载会清理键盘反馈。键盘与指针共用按压态，单个输入释放不会清掉另一输入仍保持的反馈。样式变化由视图内部处理，不需要控制器或重建内容；是否点击及何时激活仍由现有键盘回调决定，普通 ElView 不会因此合成 event.onTap。

键盘回调沿当前渲染祖先链冒泡，`originalEvent` 保留 Flutter `KeyEvent`。重复按键按 Flutter 的节奏派发，未声明 `onKeyRepeat` 时回退到 `onKeyDown`。主焦点节点的激活键仍可通过 `onTapDown`、`onTapUp` 和 `onTapCancel` 驱动反馈。

`themeMode` 控制 onDark；当前段落的文字语言提示通过 `style.textOptions.locale` 声明。

`ElView.of(context).themeMode` 返回祖先逐字段合并后的主题声明，并订阅明暗、时长和曲线变化；读取结果补齐默认的 light、200ms 和 Curves.linear。主题切换统一覆盖本次变化的样式过渡，普通按压等交互仍使用组件自己的 transition。

## 响应式与状态读取

```dart
ElView(
  breakpoint: ElBreakpoint(inheritSize: true),
  style: ElStyle(padding: EdgeInsets.all(24), sm: ElStyle(padding: EdgeInsets.all(8))),
  child: Builder(builder: (context) {
    final state = ElView.of(context);
    return Text(state.sm ? '窄布局' : '宽布局');
  }),
);
```

`breakpoint` 统一配置断点与尺寸基准：`ElBreakpoint(inheritSize: false)` 使用当前视图宽度供自身及后代判断，`true` 或未设置时继承祖先基准，无祖先则使用窗口宽度。xs/sm/md/lg/xl 是上界判断，默认 320/640/1024/1920/2560，小屏可同时命中多个档位。

ElView.of 读取最近祖先的只读状态，访问哪项就订阅哪项：hasHover、hasTap、hasFocus、hasFocusVisible、hasFocusWithin、isDisabled、isDark、themeMode 与断点属性。无祖先时用 maybeOf；需要读取当前视图时放到它的 Builder 后代中。

## 变量继承

```dart
ElView(
  style: ElStyle(
    vars: {'primary': Colors.blue},
    onDark: ElStyle(vars: {'primary': Colors.green}),
  ),
  child: Builder(builder: (context) {
    final primary = ElView.of(context).getVar<Color>('primary');
    return Text('继承变量', style: TextStyle(color: primary));
  }),
);
```

`vars` 是 `Map<Object, Object>`，key 可以是字符串、枚举或自定义对象，按 Map 的相等规则识别，不要求前缀。变量按 key 继承，近层声明及命中的变体覆盖同名值；字符串值原样保存。`getVar<T>(key)` 读取并订阅该 key，有效值变化才通知当前读取者；未定义或类型不匹配时返回 null。仅调用 `ElView.of(context)` 不登记依赖。声明后的 Map 应保持不变，通过新样式更新变量。

## 过渡与入场

```dart
final expanded = ValueNotifier(false);
ValueListenableBuilder<bool>(
  valueListenable: expanded,
  builder: (_, value, _) => ElView(
    style: ElStyle(
      width: value ? 200 : 100,
      height: 40,
      backgroundColor: Colors.blue,
      transition: [ElTransition.all(Duration(milliseconds: 200))],
      starting: ElStyle(opacity: 0),
    ),
    child: '尺寸过渡',
  ),
);
```

事件中修改 expanded.value，外部持有的 notifier 在卸载时 dispose。transition 为样式变化定义过渡，starting 定义入场起始样式；重复关键帧动画使用 animation / ElAnimation。

## 事件、焦点与语义

```dart
final focus = FocusNode();
ElView(
  focusNode: focus,
  event: ElEvent(
    onTap: (event) { event.stopPropagation(); },
    onLongPress: (_) { debugPrint('长按'); },
  ),
  semantics: ElSemantics(label: '详情区域', container: true),
  child: '长按查看详情',
);
```

| 事件组 | 常用入口 |
| --- | --- |
| 指针 | onPointerDown / Move / Up / Cancel，Enter / Exit / Hover，Signal 与 PanZoom |
| 点击 | onTap / onDoubleTap / onSecondaryTap，onTapDown / Up / Cancel |
| 拖动 | onDragStart / Update / End / Cancel，及 Horizontal / Vertical 方向组 |
| 变换 | onScaleStart / Update / End |
| 键盘与焦点 | onKeyDown / Repeat / Up、onFocus / onBlur |

原始指针按 Flutter 命中顺序派发。确认的主键点击、连击和长按从获胜节点沿命中的祖先冒泡，拖拽和缩放由 Flutter 竞技场选出的节点接收。`stopPropagation` 停止当前事件传播，按下时停止传播也会截断后续祖先登记。`preventDefault` 阻止组件的默认动作。

指针的 `onTapUp` 表示点击已被识别，物理释放使用 `onPointerUp`。点击取消和连击窗口按 Flutter 识别器处理。`ElEventConfig` 可以调整普通点击的移动容差、长按等待时间和拖动参数。

focusNode 传入后由调用方持有并 dispose；未传时，焦点样式或键盘回调可触发内部节点创建。需要标准按钮键盘行为优先用 [ElButtonView](../button/README.md)。ElSemantics 声明 label、role、状态和动作；`ElSemantics(container: true, explicitChildNodes: true)` 可建立保留后代节点的区域容器。

## 子树默认策略

ElViewProvider 的 scrollbarBuilder、refresherBuilder、smoothScrollBuilder 为滚动子树提供默认配置，示例见 [Scroll](../scroll/README.md)。普通业务无需直接使用 element / render / resolved 等内部实现。
