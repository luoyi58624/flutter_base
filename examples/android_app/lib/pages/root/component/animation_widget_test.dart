import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

const String imageUrl = 'https://images.pexels.com/photos/2286895/pexels-photo-2286895.jpeg';

class AnimationWidgetTestPage extends StatefulWidget {
  const AnimationWidgetTestPage({super.key});

  @override
  State<AnimationWidgetTestPage> createState() => _AnimationWidgetTestPageState();
}

class _AnimationWidgetTestPageState extends State<AnimationWidgetTestPage> {
  bool flag = false;

  @override
  void dispose() {
    super.dispose();
    i('animation test page销毁');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动画组件测试'),
      ),
      body: buildCenterColumn([
        ElevatedButton(
          onPressed: () {
            setState(() {
              flag = !flag;
            });
          },
          child: Text('切换颜色 - ${flag ? "绿色" : "灰色"}'),
        ),
        AnimatedColoredBox(
          duration: const Duration(milliseconds: 200),
          color: flag ? Colors.green : Colors.grey,
          child: const SizedBox(
            width: 100,
            height: 100,
          ),
        ),
        AnimatedRefreshProgressIndicator(
          duration: const Duration(milliseconds: 200),
          color: flag ? Colors.green : Colors.grey,
        )
      ]),
    );
  }
}
