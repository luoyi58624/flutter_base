import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class AnimationTestPage extends StatefulWidget {
  const AnimationTestPage({super.key});

  @override
  State<AnimationTestPage> createState() => _AnimationTestPageState();
}

class _AnimationTestPageState extends State<AnimationTestPage> with TickerProviderStateMixin {
  List<double> nums = [];
  double sliderValue = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动画测试'),
      ),
      body: Column(
        children: [
          Slider(
            value: sliderValue,
            label: '$sliderValue',
            divisions: 10,
            max: 1000,
            onChanged: (value) {
              setState(() {
                sliderValue = value;
              });
            },
          ),
          ElevatedButton(
            onPressed: () {
              AnimationUtil.createNumTween(
                vsync: this,
                begin: 0,
                end: 100,
                milliseconds: sliderValue.toInt(),
                callback: (value) {
                  nums.add(value);
                  setState(() {});
                },
              );
            },
            child: const Text('生成0-100的区间数字动画值'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                nums = [];
              });
            },
            child: const Text('清除'),
          ),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  children: [...nums.map((e) => Text('$e'))],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
