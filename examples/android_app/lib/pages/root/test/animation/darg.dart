import 'package:flutter/material.dart';

class DragAnimationTestPage extends StatefulWidget {
  const DragAnimationTestPage({super.key});

  @override
  State<DragAnimationTestPage> createState() => _DragAnimationTestPageState();
}

class _DragAnimationTestPageState extends State<DragAnimationTestPage> with SingleTickerProviderStateMixin {
  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Darg 拖拽容器测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Container(
              color: Colors.grey.shade200,
            ),
            StatefulBuilder(builder: (context, setState) {
              return Positioned(
                left: x,
                top: y,
                child: GestureDetector(
                  onPanUpdate: (e) {
                    setState(() {
                      x += e.delta.dx;
                      y += e.delta.dy;
                    });
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    color: Colors.green,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
