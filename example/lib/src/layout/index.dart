import 'package:example/src/layout/desktop/index.dart';
import 'package:example/src/layout/mobile/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ElView(
      child: Builder(
        builder: (context) {
          return ElView.of(context).sm ? MobileLayout() : DesktopLayout();
        },
      ),
    );
  }
}
