import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ElViewPage extends StatelessWidget {
  const ElViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ElView 测试')),
      body: SizedBox.expand(
        child: Row(
          children: [
            Expanded(
              child: HookBuilder(
                builder: (context) {
                  final flag = useState(false);

                  return Column(
                    spacing: 20,
                    children: [
                      RepaintBoundary(
                        child: Switch(
                          value: flag.value,
                          onChanged: (v) => flag.value = v,
                        ),
                      ),
                      ElView(
                        style: ElStyle(
                          width: flag.value ? 180 : 120,
                          height: 80,
                          backgroundColor: flag.value
                              ? Colors.blue
                              : Colors.green,
                          borderRadius: flag.value
                              ? BorderRadius.circular(40)
                              : const BorderRadius.only(
                                  topLeft: Radius.elliptical(32, 16),
                                  bottomRight: Radius.circular(16),
                                ),
                          transitions: const [ElTransition.all()],
                          clipBehavior: Clip.antiAlias,
                        ),
                        child: _radiusContent,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemBuilder: (c, i) => Center(
                            child: ElView(
                              style: .new(
                                width: 100,
                                height: 100,
                                backgroundColor: flag.value
                                    ? Colors.blue
                                    : Colors.green,
                                margin: .only(bottom: 8),
                                // transitions: [.all()],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: HookBuilder(
                builder: (context) {
                  final flag = useState(false);

                  return Column(
                    spacing: 20,
                    children: [
                      RepaintBoundary(
                        child: Switch(
                          value: flag.value,
                          onChanged: (v) => flag.value = v,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: flag.value ? 180 : 120,
                        height: 80,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: flag.value ? Colors.blue : Colors.green,
                          borderRadius: flag.value
                              ? BorderRadius.circular(40)
                              : const BorderRadius.only(
                                  topLeft: Radius.elliptical(32, 16),
                                  bottomRight: Radius.circular(16),
                                ),
                        ),
                        child: _radiusContent,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemBuilder: (c, i) => Center(
                            child: Padding(
                              padding: .only(bottom: 8),
                              child: ColoredBox(
                                color: flag.value ? Colors.blue : Colors.red,
                                child: SizedBox(width: 100, height: 100),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 半透明 child 覆盖整个盒子，便于直接观察圆角裁剪是否随动画同步。
const _radiusContent = SizedBox.expand(
  child: ColoredBox(
    color: Color(0x30ffffff),
    child: Center(
      child: Text('圆角裁剪', style: TextStyle(color: Colors.white)),
    ),
  ),
);
