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
                        child: Switch(value: flag.value, onChanged: (v) => flag.value = v),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemBuilder: (c, i) => Center(
                            child: ElView(
                              style: .new(
                                width: 100,
                                height: 100,
                                backgroundColor: flag.value ? Colors.blue : Colors.green,
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
                        child: Switch(value: flag.value, onChanged: (v) => flag.value = v),
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
