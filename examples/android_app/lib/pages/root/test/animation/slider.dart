import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

class SliderAnimationTestPage extends StatefulWidget {
  const SliderAnimationTestPage({super.key});

  @override
  State<SliderAnimationTestPage> createState() => _SliderAnimationTestPageState();
}

class _SliderAnimationTestPageState extends State<SliderAnimationTestPage> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Offset> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    animation = Tween(begin: Offset.zero, end: const Offset(3, 0)).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slider滑动动画测试'),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              AnimationUtil.switchAnimationStatus(controller);
            },
            child: const Text('开始滑动'),
          ),
          const SizedBox(height: 8),
          SlideTransition(
            position: animation,
            child: Container(
              width: 100,
              height: 100,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
