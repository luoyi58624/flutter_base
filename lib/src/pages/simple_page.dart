part of flutter_base;

class ChildPage extends StatelessWidget {
  const ChildPage({super.key, this.title, this.previousPageTitle = '返回'});

  final String? title;
  final String? previousPageTitle;

  @override
  Widget build(BuildContext context) {
    var isCupertinoApp = FlutterUtil.hasAncestorElements<CupertinoApp>(context);
    if (isCupertinoApp) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title ?? '子页面'),
          previousPageTitle: previousPageTitle,
        ),
        child: SafeArea(
          child: buildCenterColumn([
            CupertinoButton.filled(
              onPressed: () {
                RouterUtil.push(context, ChildPage(title: title ?? '子页面'));
              },
              child: const Text('进入下一个子页面'),
            ),
            CupertinoButton.filled(
              onPressed: () {
                RouterUtil.pop(context);
              },
              child: const Text('返回'),
            ),
          ]),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text(title ?? '子页面'),
        ),
        body: buildCenterColumn([
          ElevatedButton(
            onPressed: () {
              RouterUtil.push(context, ChildPage(title: title ?? '子页面'));
            },
            child: const Text('进入下一个子页面'),
          ),
          ElevatedButton(
            onPressed: () {
              RouterUtil.pop(context);
            },
            child: const Text('返回'),
          ),
        ]),
      );
    }
  }
}
