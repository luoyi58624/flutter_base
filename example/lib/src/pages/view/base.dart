import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ViewBasePage extends HookWidget {
  const ViewBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ElView 基础使用')),
      body: ElScrollView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  ElView(
                    child: Builder(
                      builder: (context) {
                        final state = ElView.of(context);
                        return ElView(
                          style: .new(
                            width: 100,
                            height: 100,
                            padding: .all(16),
                            backgroundColor: state.hasTap
                                ? Colors.green
                                : state.hasHover
                                ? Colors.purple
                                : Colors.blue,
                            borderRadius: .circular(8),
                            transform: .scale(
                              state.hasTap
                                  ? 0.9
                                  : state.hasHover
                                  ? 1.5
                                  : 1.0,
                            ),
                            transition: [
                              .all(
                                state.hasTap
                                    ? .zero
                                    : Duration(milliseconds: 250),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
