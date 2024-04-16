import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'child.dart';
import 'sliver.dart';

class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key});

  @override
  State<TemplatePage> createState() => TemplatePageState();
}

class TemplatePageState extends State<TemplatePage> with SingleTickerProviderStateMixin {
  int count = 0;

  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: const Duration(milliseconds: 5000), vsync: this);
    animation = Tween(begin: 300.0, end: 600.0).animate(controller);
    // controller.repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void addCount() {
    setState(() {
      count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('模板列表'),
        ),
        body: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Container(
            height: animation.value,
            decoration: const BoxDecoration(
              color: Colors.grey,
            ),
            child: fontDemo,
          ),
        ));
  }

  Widget get fontDemo => buildCenterColumn([
        IconButton(onPressed: () {}, icon: const Icon(Icons.ac_unit)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            AnimationUtil.switchAnimationStatus(controller);
          },
          child: const Text('开始动画'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            RouterUtil.push(context, const SliverTestPage());
          },
          child: const Text('Sliver'),
        ),
        const SizedBox(height: 8),
        Hero(
          tag: 'button',
          child: GestureDetector(
            onTap: () {
              RouterUtil.push(context, const _HeroChildPage(), rootNavigator: true);
            },
            child: Container(
              width: 100,
              height: 100,
              color: Colors.green,
            ),
          ),
        ),
      ]);
}

class _HeroChildPage extends StatelessWidget {
  const _HeroChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero动画子页面'),
      ),
      body: Hero(
        tag: 'button',
        child: Container(
          height: 100,
          decoration: const BoxDecoration(
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}
