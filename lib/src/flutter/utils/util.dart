import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:flutter/widgets.dart';

/// 提供 Flutter 元素查询、坐标、键盘与尺寸工具。
class ElFlutterUtil {
  ElFlutterUtil._();

  /// 刷新整个应用，调用此方法的效果相当于执行热重载。
  /// 注意：此方法非常昂贵，你应当在 UI 空闲时调用此方法。
  static void refreshApp() {
    WidgetsBinding.instance.reassembleApplication();
  }

  /// 通过当前 context，检查祖先是否存在某个 Widget
  static bool hasAncestorWidget<T extends Widget>(BuildContext context) =>
      context.findAncestorWidgetOfExactType<T>() != null;

  /// 通过当前 context，获取最近的目标祖先 Element
  static Element? getAncestorElement<T extends Widget>(BuildContext context) {
    Element? element;
    context.visitAncestorElements((e) {
      if (e.widget is T) {
        element = e;
        return false;
      }
      return true;
    });
    return element;
  }

  /// 访问指定类型 State 的后代元素，注意：对于拥有多个子项的 Widget，它只会访问第一条数据并进行递归
  static T? findDescendantStateOfType<T extends State>(
    BuildContext context, [
    BuildContext? parentContext,
  ]) {
    Element? element;
    (parentContext ?? context).visitChildElements((v) => element ??= v);
    if (element == null) return null;
    if (element is StatefulElement) {
      final state = (element as StatefulElement).state;
      if (state is T) {
        return state;
      }
    }

    return findDescendantStateOfType<T>(context, element);
  }

  /// 从当前 context 获取元素的坐标位置，你还可以传递另一个 Widget 的 context 作为参数，计算相对坐标
  static Offset getPosition(
    BuildContext context, [
    BuildContext? relativeContext,
  ]) {
    late Offset offset;
    final renderBox = context.findRenderObject() as RenderBox;
    offset = renderBox.localToGlobal(Offset.zero);
    if (relativeContext != null) {
      final relativeRenderBox = relativeContext.findRenderObject() as RenderBox;
      final relativeOffset = relativeRenderBox.localToGlobal(Offset.zero);
      offset = Offset(
        offset.dx - relativeOffset.dx,
        offset.dy - relativeOffset.dy,
      );
    }
    return offset;
  }

  /// 从当前 context 获取元素的坐标 + 宽高，你还可以传递另一个 Widget 的 context 作为参数，计算相对坐标
  static Rect getRect(BuildContext context, [BuildContext? relativeContext]) {
    final position = getPosition(context, relativeContext);
    final s = context.size!;
    return Rect.fromLTWH(position.dx, position.dy, s.width, s.height);
  }

  // /// 访问后代最深层的 Focus 焦点
  // FocusNode? getChildFocusNode([BuildContext? context]) {
  //   FocusNode? focusNode;
  //   Element? element;
  //
  //   visitChildElements((v) => element ??= v);
  //
  //   if (element == null) return null;
  //
  //   if (element!.widget is Focus) {
  //     final result = (element as StatefulElement).state as ElEventState;
  //     if (result.focusNode != null) {
  //       return result;
  //     } else {
  //       return getChildFocusEvent(element!);
  //     }
  //   } else {
  //     return getChildFocusEvent(element!);
  //   }
  // }

  /// 隐藏手机软键盘但保留焦点
  static Future<void> hideKeyboard() async {
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// 显示手机软键盘
  static Future<void> showKeyboard() async {
    await SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  /// 隐藏手机软键盘并失去焦点
  static Future<void> unFocus() async {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 计算限制后的元素尺寸，返回类似于自适应大小的图片尺寸
  static Size calcConstraintsSize(Size size, BoxConstraints constraints) {
    final double originalWidth = size.width;
    final double originalHeight = size.height;

    // 处理原始尺寸宽度或高度为0的情况
    if (originalWidth == 0) {
      return Size(0, constraints.maxHeight.clamp(0.0, constraints.maxHeight));
    }
    if (originalHeight == 0) {
      return Size(constraints.maxWidth.clamp(0.0, constraints.maxWidth), 0);
    }

    // 计算宽度和高度方向的缩放比例（考虑max为无穷大的情况）
    final double scaleX = constraints.maxWidth.isInfinite
        ? double.infinity
        : constraints.maxWidth / originalWidth;
    final double scaleY = constraints.maxHeight.isInfinite
        ? double.infinity
        : constraints.maxHeight / originalHeight;

    // 取较小的比例因子以保证不超出任一约束
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // 计算缩放后的尺寸，并确保不超过约束（防止浮点误差）
    final double constrainedWidth = (originalWidth * scale).clamp(
      0.0,
      constraints.maxWidth,
    );
    final double constrainedHeight = (originalHeight * scale).clamp(
      0.0,
      constraints.maxHeight,
    );

    return Size(constrainedWidth, constrainedHeight);
  }

  /// 访问当前视图，如果不传递 context，则访问全局实例中的第一个视图，
  /// 若传递 context，则返回目标 context 所在的视图
  static FlutterView? getCurrentView([BuildContext? context]) => context == null
      ? WidgetsBinding.instance.platformDispatcher.views.firstOrNull
      : View.maybeOf(context);

  /// 获取当前视图所在显示器的 fps 帧率
  static double? getFps([BuildContext? context]) =>
      getCurrentView(context)?.display.refreshRate;
}
