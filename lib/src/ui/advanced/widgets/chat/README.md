# 聊天

`ElChatScroll` 接收按最旧到最新排列的消息，显示自己和对方的消息。默认支持文字、图片预览和文件卡片。用 `avatarBuilder` 替换头像，用 `messageBuilder` 覆盖已有气泡或渲染继承 `ElChatMessage` 的业务类型。

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

// 在安装移动或桌面组件预设的页面内使用。
Column(
  children: [
    Expanded(
      child: ElChatScroll(
        messages: messages,
        controller: chatController,
        onLoadEarlier: hasEarlier ? loadEarlier : null,
        onOpenFile: openFile,
        sliverBuilder: (context, delegate) => SliverList(delegate: delegate),
      ),
    ),
    ElChatComposer(
      modelValue: draft,
      onSend: sendText,
      actions: [ElButton(onPressed: pickFile, child: '附件')],
    ),
  ],
)
```

- 应用持有消息。历史插到前面，新消息加到末尾，修改正文时保持 ID 并传入新的消息快照。
- `sliverBuilder` 接收最新消息在序号 0 的 `SliverChildBuilderDelegate`。省略时使用 `ElSliverList.recycler`。自定义列表沿滚动轴按委托序号布局，保留委托生成的行和 Key。
- `jumpToMessage(id)` 定位已加载消息，`jumpToLatest()` 和 `animateToLatest()` 回到最新端，`atLatest` 可用于显示未读提示。自定义 Sliver 的离屏定位需要逐段查找。
- `ElChatComposer` 支持多行输入。桌面按 Enter 发送，Shift+Enter 换行，IME 组字交给输入法。发送回调返回 `true` 后清除本次草稿，返回 `false` 时保留草稿。`panel` 可放表情或附件面板。
