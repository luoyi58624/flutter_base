# Skeleton

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/skeleton` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElSkeleton | `skeletonBuilder` |
| ElSkeletonItem | `skeletonItemBuilder` |

辅助类型：`ElSkeletonVariant`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElSkeleton | loading | `bool` | 当前是否展示加载骨架。 |
| ElSkeleton | rows | `num` | 默认模板的正文行数，具体归一化规则由品牌实现处理。 |
| ElSkeleton | animated | `bool` | 启用品牌骨架动画。 |
| ElSkeleton | avatar | `bool` | 默认模板中包含头像占位。 |
| ElSkeleton | child | `Widget?` | 加载完成后的正文内容。 |
| ElSkeleton | template | `Widget?` | 自定义骨架模板，通常组合 ElSkeletonItem。 |
| ElSkeleton | style | `ElStyle?` | 骨架根样式。 |
| ElSkeleton | semanticLabel | `String?` | 辅助技术读取的加载说明。 |
| ElSkeletonItem | variant | `ElSkeletonVariant` | 骨架块的语义形态。 |
| ElSkeletonItem | width | `Object?` | 显式宽度，接受逻辑像素或百分比字符串。 |
| ElSkeletonItem | height | `Object?` | 显式高度，接受逻辑像素或百分比字符串。 |
| ElSkeletonItem | style | `ElStyle?` | 单个骨架块的样式。 |

rows 使用 num、补充移动端 avatar 配置，保留桌面 template/animated 配置；不归一化行数、不保留或隐藏正文、不创建动画。移动端参照 lib/src/ui/mobile/components/skeleton/index.dart。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
