# Link

带导航语义的链接，无需品牌组件。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElLink(
  href: 'https://example.com',
  target: LinkTarget.blank,
  style: ElStyle(color: Colors.blue, onHover: ElStyle(decoration: TextDecoration.underline)),
  child: '查看详情',
);
```

| 参数 | 用途 |
| --- | --- |
| href | String 或 Uri；空值退化为只执行回调的行为链接 |
| target | self 为当前上下文，blank 为新窗口或外部打开 |
| onPressed | 激活回调，可与 href 默认导航组合 |
| event | 自定义事件，event.preventDefault 阻止默认导航 |
| disabled / selected | 禁用状态、选择语义，已选外观由业务设置 |
| semanticLabel / focusNode | 辅助名称与外部焦点节点 |
| style / child | 文本、盒模型、状态样式和内容 |

## 拦截导航或只执行操作

```dart
ElLink(
  href: Uri.parse('https://example.com'),
  event: ElEvent(onTap: (event) {
    event.preventDefault();
    debugPrint('由业务接管路由');
  }),
  child: '内部打开',
);
ElLink(onPressed: () {}, child: '纯操作链接');
```

键盘只有 Enter 激活；Space 保留滚动行为，文字可正常选择。Web 端有 href 时使用原生链接层支持浏览器右键菜单和修饰键多开；非 Web 端自动接入地址预览和复制链接菜单。

ElLinkStatusBar.enabled 可全局关闭地址预览，showDelay / hideDelay、showFadeDuration / hideFadeDuration、expandDelay / expandDuration 调整时序。自定义链接可调用 hoverEnter(context, uri) / hoverExit(uri)，需要官方 Overlay 才显示；通常 ElLink 已自动接线。外部 focusNode 在卸载时 dispose。
