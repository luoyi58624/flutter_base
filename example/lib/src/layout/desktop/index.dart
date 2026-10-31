import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

part 'sidebar.dart';

class DesktopLayout extends StatelessWidget {
  const DesktopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    ElLog.i('build');
    return Scaffold(
      body: SizedBox.expand(
        child: Row(
          children: [
            ElView(
              style: .new(width: 200, height: '100%', bgColor: Colors.green),
            ),
            Expanded(
              child: ElView(
                style: .new(width: 200, height: '100%', bgColor: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
