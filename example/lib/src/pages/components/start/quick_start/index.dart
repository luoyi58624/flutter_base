import 'package:flutter/widgets.dart';

import '../../../../widgets/code_preview/index.dart';
import '../../../../widgets/docs_page/index.dart';

/// 介绍 flutter_base 的安装方式和最小应用。
class QuickStartPage extends StatelessWidget {
  /// 创建快速开始页面。
  const QuickStartPage({super.key});

  @override
  Widget build(BuildContext context) => DocsPage(
    title: '快速开始',
    navTitle: '快速开始',
    description: '安装 flutter_base，在 Flutter 应用中显示第一个 ElButton。',
    sections: [
      DocsSection(
        title: '安装依赖',
        description: '使用 Flutter 3.44.0 或以上版本，并确保 Dart 满足 ^3.13.4。在项目的 pubspec.yaml 中添加 Git 依赖。',
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            ElCodePreview(lang: 'yaml', code: _dependency),
            Text('保存后，在项目目录安装依赖。'),
            ElCodePreview(lang: 'bash', code: 'flutter pub get'),
          ],
        ),
      ),
      DocsSection(
        title: '快速入门',
        description: '将以下代码放入 lib/main.dart。ElComponentProvider 为页面内的组件安装移动端预设。',
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            ElCodePreview(code: _main),
            Text('桌面应用可导入 package:flutter_base/desktop.dart，并把 el.mobileComponents 换成 el.desktopComponents。'),
            Text('保存后运行应用。'),
            ElCodePreview(lang: 'bash', code: 'flutter run'),
          ],
        ),
      ),
    ],
  );
}

const _dependency = '''
dependencies:
  flutter_base:
    git:
      url: https://github.com/luoyi58624/flutter_base.git
''';

const _main = '''
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: ElComponentProvider(
        components: el.mobileComponents,
        child: Scaffold(
          body: Center(
            child: ElButton(
              type: .primary,
              onPressed: () {},
              child: '你好，El UI',
            ),
          ),
        ),
      ),
    ),
  );
}
''';
