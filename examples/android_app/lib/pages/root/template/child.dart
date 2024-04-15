import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class TemaplteChildPage extends StatelessWidget {
  const TemaplteChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          '子页面',
        ),
        previousPageTitle: '模板列表',
        // previousPageTitle: 'Back',
      ),
      child: Center(
        child: Text(
          'hello 你好',
          style: TextStyle(backgroundColor: Colors.red, fontSize: 24),
        ),
      ),
    );
  }
}

class TemaplteChildPage2 extends StatelessWidget {
  const TemaplteChildPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            '子页面2',
          ),
          previousPageTitle: '模板列表',
        ),
        child: Center(
          child: Text('hello'),
        ));
  }
}

class TemplateChildPage3 extends StatelessWidget {
  const TemplateChildPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('子页面3'),
      ),
      body: buildCenterColumn([
        const Text(
          'hello 你好',
          style: TextStyle(backgroundColor: Colors.red, fontSize: 24),
          strutStyle: StrutStyle(
              // forceStrutHeight: true,
              ),
        ),
        const SizedBox(height: 18),
        const Text(
          'hello 你好',
          style: TextStyle(backgroundColor: Colors.red, fontSize: 24),
          strutStyle: StrutStyle(
            forceStrutHeight: true,
          ),
        ),
      ]),
    );
  }
}
