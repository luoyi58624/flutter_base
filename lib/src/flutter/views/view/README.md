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

`themeMode` 控制 onDark，`locale` 提供文字语言提示；二者与样式环境沿视图链传递。

## 响应式与状态读取

```dart
ElView(
  inheritSize: true,
  style: ElStyle(padding: EdgeInsets.all(24), sm: ElStyle(padding: EdgeInsets.all(8))),
  child: Builder(builder: (context) {
    final state = ElView.of(context);
    return Text(state.sm ? '窄布局' : '宽布局');
  }),
);
```

`breakpoint` 可覆写断点，inheritSize 为后代提供响应式尺寸基准。xs/sm/md/lg/xl 是上界判断，默认 320/640/1024/1920/2560，小屏可同时命中多个档位。

ElView.of 读取最近祖先的只读状态，访问哪项就订阅哪项：hasHover、hasTap、hasFocus、hasFocusVisible、hasFocusWithin、isDisabled、isDark 与断点属性。无祖先时用 maybeOf；需要读取当前视图时放到它的 Builder 后代中。

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

ElEventDetails 提供事件上下文与 stopPropagation / preventDefault；前者停止传播，后者阻止默认动作。ElEventConfig 配置点击、双击和拖动识别参数；高级拖动协作使用 ElDragProxy。

focusNode 传入后由调用方持有并 dispose；未传时，焦点样式或键盘回调可触发内部节点创建。需要标准按钮键盘行为优先用 [ElButtonView](../button/README.md)。ElSemantics 声明 label、role、状态和动作；ElCardView 可建立保留后代节点的区域容器。

## 子树默认策略

ElViewProvider 的 scrollbarBuilder、refresherBuilder、smoothScrollBuilder 为滚动子树提供默认配置，示例见 [Scroll](../scroll/README.md)。普通业务无需直接使用 element / render / resolved 等内部实现。
