# Avatar

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/avatar` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElAvatar | `avatarBuilder` |
| ElAvatarGroup | `avatarGroupBuilder` |

辅助类型：`ElAvatarShape`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElAvatar | child | `Object?` | 图片与图标之外的头像内容。 |
| ElAvatar | icon | `Object?` | 头像图标，接受 IconData 或 Widget。 |
| ElAvatar | src | `String?` | 头像图片地址。 |
| ElAvatar | alt | `String?` | 图片替代文字。 |
| ElAvatar | size | `double?` | 显式头像边长，未指定时由品牌实现决定。 |
| ElAvatar | shape | `ElAvatarShape?` | 头像形状，未指定时可由头像组提供。 |
| ElAvatar | fit | `BoxFit` | 图片填充方式。 |
| ElAvatar | onTap | `VoidCallback?` | 头像激活回调。 |
| ElAvatar | disabled | `bool` | 禁止头像交互。 |
| ElAvatar | style | `ElStyle?` | 组件根样式。 |
| ElAvatar | semanticLabel | `String?` | 辅助技术读取的组件名称。 |
| ElAvatarGroup | children | `List<Widget>` | 头像成员列表。 |
| ElAvatarGroup | size | `double?` | 成员未显式指定时采用的头像边长。 |
| ElAvatarGroup | shape | `ElAvatarShape?` | 成员未显式指定时采用的头像形状。 |
| ElAvatarGroup | max | `int?` | 最多显示的头像数量，null 表示全部。 |
| ElAvatarGroup | gap | `double` | 相邻头像的逻辑间距，负值表示叠放。 |
| ElAvatarGroup | style | `ElStyle?` | 组件根样式。 |
| ElAvatarGroup | collapseStyle | `ElStyle?` | 折叠数量提示的样式。 |
| ElAvatarGroup | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

size 仅保留 double 逻辑边长，不引入 ElLevelType 品牌档位；头像组上下文和折叠计数留给品牌。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
