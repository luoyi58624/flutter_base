import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ExitWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('首页'),
        ),
        body: Container(),
      ),
    );
  }
}

class ExitWidget extends StatefulWidget {
  const ExitWidget({super.key, required this.child});

  final Widget child;

  @override
  State<ExitWidget> createState() => _ExitWidgetState();
}

class _ExitWidgetState extends State<ExitWidget> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: widget.child,
        onWillPop: () async {
          return false;
        });
  }
}
