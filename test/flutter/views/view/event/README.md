# ElEvent 测试

事件代码在 `lib/src/flutter/views/view/event/`。`dispatcher.dart` 接入 RenderBox 和冒泡，`gestures.dart` 转发 Flutter 识别器的点击、连击、长按、拖拽与缩放。`event.dart` 和 `details.dart` 声明回调、配置与事件详情。

## 拖拽与缩放

- `onDragDown` 是主指针或触控板的候选通知。只订阅此回调的宿主只观察输入。在这一阶段调用 `stopPropagation()` 会截断后续 ElEvent 宿主的拖拽报名。
- Flutter 竞技场裁决拖拽和缩放。正式手势阶段发给获胜宿主，起手容差、轴向竞争和速度估算交给对应的 Flutter 识别器。
- 事件详情补充触发回调的原始指针事件、坐标、累计位移和终态原因。拖拽累计值从正式开始后的更新累加。缩放跟随 Flutter 在触点组合变化时结算。
- 物理取消、禁用、卸载或更换事件结构时，已开始的手势只结清一次。回调结构和配置相等时，重建替换闭包，当前手势继续。
- 新增的拖拽识别器从下一次指针按下开始报名。组件的跨节点位移交接由组件自己的迁移用例覆盖。

## 验证范围

| 文件 | 覆盖内容 |
| --- | --- |
| `drag_gesture_contract_test.dart`、`drag_interaction_test.dart` | 候选按下、拖拽容差、轴向、速度和累计位移 |
| `scale_gesture_contract_test.dart`、`scale_two_finger_test.dart` | 原始触控板输入、缩放竞争、双指旋转和触点变化 |
| `event_lifecycle_contract_test.dart`、`drag_replacement_tap_test.dart`、`event_dispatch_reentrancy_test.dart` | 启停、重建、回调重入和单次终态 |
| `event_propagation_contract_test.dart`、`prevent_default_contract_test.dart` | 命中路线、传播截断和业务默认动作 |
| `event_metadata_test.dart`、`event_callback_order_contract_test.dart` | 指针元数据、坐标和阶段顺序 |
| `event_view_test.dart` | 真实 ElView 接线、官方 ListView 竞争、禁用和卸载 |
| `tap_gesture_contract_test.dart` | Flutter 连击计数、长按竞争与纯样式按压 |

协议测试共用 `support/dispatcher_test_host.dart`，按命中顺序登记宿主后由 Flutter 路由输入。Widget 测试使用默认 `TestWidgetsFlutterBinding`。

```powershell
flutter test --no-pub --concurrency=1 test/flutter/views/view/event
```
