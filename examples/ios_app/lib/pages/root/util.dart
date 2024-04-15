import 'package:flutter/cupertino.dart';
import 'package:flutter_base/flutter_base.dart';

class UtilPage extends StatelessWidget {
  const UtilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('工具'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 8),
              CupertinoButton.filled(
                onPressed: () {
                  context.go('/util/child?title=工具 - 子页面');
                },
                child: const Text('子页面'),
              ),
              const SizedBox(height: 8),
              CupertinoButton.filled(
                onPressed: () {
                  RouterUtil.push(context, const _FirstPage());
                },
                child: const Text('一级子页面'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstPage extends StatelessWidget {
  const _FirstPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('一级子页面'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              CupertinoButton.filled(
                onPressed: () {
                  RouterUtil.push(context, const _SecondPage());
                },
                child: const Text('二级子页面'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondPage extends StatelessWidget {
  const _SecondPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('二级子页面'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              CupertinoButton.filled(
                onPressed: () {
                  RouterUtil.push(context, const _ThreePage());
                },
                child: const Text('三级子页面'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreePage extends StatelessWidget {
  const _ThreePage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('三级子页面'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              CupertinoButton.filled(
                onPressed: () {
                  RouterUtil.popUntil(context, '/util');
                  // context.go('/');
                },
                child: const Text('返回工具页面'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
