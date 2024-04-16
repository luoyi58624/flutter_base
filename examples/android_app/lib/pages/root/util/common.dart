import 'package:android_app/mixins/common_mixin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ToastTestPage extends StatelessWidget with CupertinoPageMixin {
  const ToastTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appTheme = FlutterController.of.getTheme(context);
    return Material(
      child: buildScaffold(
        context,
        title: 'Toast测试',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton.filled(
                onPressed: () async {
                  ToastUtil.showPrimaryToast('你好');
                },
                child: const Text('Toast'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                color: appTheme.primary,
                onPressed: () async {
                  ToastUtil.showPrimaryToast('你好');
                },
                child: const Text('Primary Toast'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                color: appTheme.success,
                onPressed: () async {
                  ToastUtil.showSuccessToast('hello');
                },
                child: const Text('Success Toast'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                color: appTheme.warning,
                onPressed: () async {
                  ToastUtil.showWarningToast('hello');
                },
                child: const Text('Warning Toast'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                color: appTheme.error,
                onPressed: () async {
                  ToastUtil.showErrorToast('hello');
                },
                child: const Text('Error Toast'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                color: appTheme.info,
                onPressed: () async {
                  ToastUtil.showInfoToast('hello');
                },
                child: const Text('Info Toast'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                color: appTheme.info,
                onPressed: () async {
                  ToastUtil.showInfoToast('xasnxkasnxkajsnxjkasnxkjasnxk谢娜看下杰卡斯你显卡是那些卡死你显卡是想那就可实现那是可能性卡死你');
                },
                child: const Text('长Toast'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingTestPage extends StatelessWidget with CupertinoPageMixin {
  const LoadingTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return buildScaffold(
      context,
      title: '自定义全局Loading',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoButton.filled(
              onPressed: () async {
                LoadingUtil.show('加载中...', delayClose: 3000);
                await 1.delay();
                LoadingUtil.close();
              },
              child: const Text('1秒后延迟关闭Loading'),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () async {
                LoadingUtil.show('加载中...', delayClose: 3000);
                await 1.delay();
                LoadingUtil.close(true);
              },
              child: const Text('1秒后立即关闭Loading'),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () async {
                LoadingUtil.show('加载中...');
                await 2.delay();
                LoadingUtil.close();
              },
              child: const Text('2秒后关闭Loading'),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () async {
                LoadingUtil.show('加载中...');
                await 0.05.delay();
                LoadingUtil.close();
              },
              child: const Text('50毫秒后关闭Loading'),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () async {
                LoadingUtil.show('加载中...');
                await 0.2.delay();
                LoadingUtil.show('加载中信息...');
                await 0.4.delay();
                LoadingUtil.show('西安市西安市...');
                await 0.1.delay();
                LoadingUtil.show('加载啊啊想啊想啊伤心啊是中...');
                await 0.6.delay();
                LoadingUtil.show('加嘻嘻嘻载中...');
                await 0.2.delay();
                LoadingUtil.close();
              },
              child: const Text('多重Loading'),
            ),
          ],
        ),
      ),
    );
  }
}

class ColorTestPage extends StatefulWidget {
  const ColorTestPage({super.key});

  @override
  State<ColorTestPage> createState() => _ColorTestPageState();
}

class _ColorTestPageState extends State<ColorTestPage> {
  @override
  Widget build(BuildContext context) {
    var appTheme = FlutterController.of.getTheme(context);
    List colorSwatch = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
    List<Color> colorList = [
      ...colorSwatch.map((e) => Colors.cyan[e]!),
      ...colorSwatch.map((e) => Colors.green[e]!),
      ...colorSwatch.map((e) => Colors.amber[e]!),
      ...colorSwatch.map((e) => Colors.indigo[e]!),
      ...colorSwatch.map((e) => Colors.blue[e]!),
      ...colorSwatch.map((e) => Colors.red[e]!),
      ...colorSwatch.map((e) => Colors.purple[e]!),
      ...colorSwatch.map((e) => Colors.blueGrey[e]!),
      ...colorSwatch.map((e) => Colors.brown[e]!),
      ...colorSwatch.map((e) => Colors.yellow[e]!),
      ...colorSwatch.map((e) => Colors.teal[e]!),
      ...colorSwatch.map((e) => Colors.lightBlue[e]!),
      ...colorSwatch.map((e) => Colors.lime[e]!),
      ...colorSwatch.map((e) => Colors.lightGreen[e]!),
      ...colorSwatch.map((e) => Colors.grey[e]!),
      ...colorSwatch.map((e) => Colors.pink[e]!),
      ...colorSwatch.map((e) => Colors.deepOrange[e]!),
      Colors.blueAccent,
      Colors.amberAccent,
      Colors.greenAccent,
      Colors.redAccent,
      Colors.white,
      Colors.black,
      appTheme.primary,
      appTheme.success,
      appTheme.warning,
      appTheme.error,
      appTheme.info,
    ];
    var bottom = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('颜色测试'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ...colorList.map((e) => Container(
                  color: e,
                  width: double.infinity,
                  height: 50,
                  child: Center(
                    child: Text(
                      '${ColorUtil.isDark(e) ? '深色' : '浅色'} ---- ${ColorUtil.getColorHsp(e)}',
                      style: TextStyle(
                        color: ColorUtil.isDark(e) ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                )),
            TextField(
              decoration: InputDecoration(hintText: "  ViewInsets.bottom =  $bottom"),
            ),
          ],
        ),
      ),
    );
  }
}

class ColorTestPage2 extends StatelessWidget with CupertinoPageMixin {
  const ColorTestPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return buildScaffold(context,
        title: '测试颜色变亮变暗',
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(21, (index) => 0.1 * index)
                .toList()
                .map(
                  (e) => Container(
                    width: double.infinity,
                    height: 100,
                    color: ColorUtil.getLightnessColor(Colors.blue, e),
                    child: Center(
                      child: Text(
                        '亮度：${e.toStringAsFixed(2)} - hsp值：${ColorUtil.getColorHsp(ColorUtil.getLightnessColor(Colors.blue, e))}',
                        style: TextStyle(
                          color: ColorUtil.isDark(ColorUtil.getLightnessColor(Colors.blue, e))
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ));
  }
}

class SwitchAnimateTestPage extends StatefulWidget {
  const SwitchAnimateTestPage({super.key});

  @override
  State<SwitchAnimateTestPage> createState() => _SwitchAnimateTestPageState();
}

class _SwitchAnimateTestPageState extends State<SwitchAnimateTestPage> with CupertinoPageMixin {
  IconData _actionIcon = Icons.delete;

  @override
  Widget build(BuildContext context) {
    return buildScaffold(
      context,
      title: '切换动画',
      child: Center(
        child: AnimatedSwitcher(
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          duration: const Duration(milliseconds: 500),
          child: IconButton(
            key: ValueKey(_actionIcon),
            onPressed: () {
              setState(() {
                if (_actionIcon == Icons.delete) {
                  _actionIcon = Icons.done;
                } else {
                  _actionIcon = Icons.delete;
                }
              });
            },
            icon: Icon(_actionIcon),
          ),
        ),
      ),
    );
  }
}

class BigDataTestPage extends StatefulWidget {
  const BigDataTestPage({super.key});

  @override
  State<BigDataTestPage> createState() => _BigDataTestPageState();
}

class _BigDataTestPageState extends State<BigDataTestPage> with CupertinoPageMixin {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return buildScaffold(
      context,
      title: '大数据测试',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4 / 1,
          children: List.generate(
            10000,
            (index) => ElevatedButton(
              onPressed: () {
                setState(() {
                  count++;
                });
              },
              child: Text('button-$index: $count'),
            ),
          ),
        ),
      ),
    );
  }
}

// class CookieTestPage extends StatelessWidget with CupertinoPageMixin {
//   const CookieTestPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: const Text('Cookie测试'),
//         ),
//         body: Center(
//           child: ElevatedButton(
//             onPressed: () async {
//               final cookieJar = CookieJar();
//               List<Cookie> cookies = [Cookie('name', 'wendux'), Cookie('location', 'china')];
//               // Saving cookies.
//               await cookieJar.saveFromResponse(Uri.parse('https://webs.mowork.cn'), cookies);
//               // Obtain cookies.
//               List<Cookie> results = await cookieJar.loadForRequest(Uri.parse('https://www.baidu.com'));
//               LoggerUtil.i(results);
//             },
//             child: const Text('获取设置的cookie'),
//           ),
//         ));
//   }
// }

class BadgeTestPage extends StatefulWidget {
  const BadgeTestPage({super.key});

  @override
  State<BadgeTestPage> createState() => _BadgeTestPageState();
}

class _BadgeTestPageState extends State<BadgeTestPage> {
  int i = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge.count(
              count: i,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    i++;
                  });
                },
                child: Text('count: $i'),
              ),
            ),
            BadgeWidget(
              bagde: i,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    i++;
                  });
                },
                child: Text('count: $i'),
              ),
            ),
            Badge(
              label: Container(
                height: 30,
                constraints: const BoxConstraints(minWidth: 12),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    i.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              padding: EdgeInsets.zero,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    i += 10;
                  });
                },
                child: Text(
                  'count: $i',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  i = 0;
                });
              },
              child: const Text('重置'),
            ),
          ],
        ),
      ),
    );
  }
}
