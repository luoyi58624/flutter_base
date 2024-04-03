part of flutter_base;

/// 点击空白区域隐藏软键盘widget
class HideKeybordWidget extends StatelessWidget {
  const HideKeybordWidget({super.key, required this.child, this.onlyHideKeybord});

  final Widget child;
  final bool? onlyHideKeybord; // 仅仅隐藏键盘，保留焦点

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: child,
      onTap: () async {
        if (onlyHideKeybord != null && onlyHideKeybord == true) {
          await SystemChannels.textInput.invokeMethod('TextInput.hide');
        } else {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        }
      },
    );
  }
}
