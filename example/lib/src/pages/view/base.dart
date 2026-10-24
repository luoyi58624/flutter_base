import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ViewBasePage extends HookWidget {
  const ViewBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ElView 基础使用')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                ElEventView(
                  child: Builder(
                    builder: (context) {
                      return ElView(
                        style: .new(
                          width: 100,
                          height: 100,
                          padding: .all(16),
                          backgroundColor: context.hasTap
                              ? Colors.green
                              : context.hasHover
                              ? Colors.purple
                              : Colors.blue,
                          borderRadius: .circular(8),
                          transform: .scale(
                            context.hasTap
                                ? 0.9
                                : context.hasHover
                                ? 1.5
                                : 1.0,
                          ),
                          transitions: [.all(context.hasTap ? .zero : Duration(milliseconds: 250))],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
