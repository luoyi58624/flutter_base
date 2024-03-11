part of flutter_base;

class FlutterUtil {
  FlutterUtil._();

  /// 当flutter渲染完毕元素后再执行异步逻辑
  static void nextTick(Future<void> Function() fun) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await fun();
    });
  }

  /// 隐藏手机软键盘但保留焦点
  static Future<void> hideKeybord() async {
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// 显示手机软键盘
  static Future<void> showKeybord() async {
    await SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  /// 隐藏手机软键盘并失去焦点
  static Future<void> unfocus() async {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// 检查当前所处的组件是否包含某个祖先widget
  static bool hasAncestorElements<T>(BuildContext context) {
    bool flag = false;
    context.visitAncestorElements((element) {
      if (element.widget is T) {
        flag = true;
        return false;
      }
      return true;
    });
    return flag;
  }
}
