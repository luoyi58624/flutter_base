# Empty

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/empty` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElEmpty | `emptyBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElEmpty | description | `Object?` | 空状态说明内容。 |
| ElEmpty | image | `Object?` | 自定义插画地址或 Widget。 |
| ElEmpty | imageSize | `double?` | 插画的显式逻辑边长。 |
| ElEmpty | child | `Object?` | 底部操作区域内容。 |
| ElEmpty | style | `ElStyle?` | 组件根样式。 |
| ElEmpty | imageStyle | `ElStyle?` | 插画样式。 |
| ElEmpty | descriptionStyle | `ElStyle?` | 说明内容样式。 |
| ElEmpty | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

不绘制默认插画或加载图片；既有 ElEmptyWidget 零尺寸基元保持独立。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
