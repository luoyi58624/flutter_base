import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class MyData {
  static InheritedWidgetTestPageState? of(BuildContext context) {
    MyInheritedWidget? myInheritedWidget = context.dependOnInheritedWidgetOfExactType<MyInheritedWidget>();
    return myInheritedWidget?.instance;
  }
}

/// 用于向子组件共享的表单数据
class MyInheritedWidget extends InheritedWidget {
  const MyInheritedWidget({
    super.key,
    required super.child,
    required this.instance,
  });

  final InheritedWidgetTestPageState instance;

  @override
  bool updateShouldNotify(MyInheritedWidget oldWidget) {
    // return oldWidget.count != count;
    return true;
  }
}

class InheritedWidgetTestPage extends StatefulWidget {
  const InheritedWidgetTestPage({super.key});

  @override
  State<InheritedWidgetTestPage> createState() => InheritedWidgetTestPageState();
}

class InheritedWidgetTestPageState extends State<InheritedWidgetTestPage> {
  int count = 0;

  void increment() {
    setState(() {
      count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('InheritedWidget测试'),
      ),
      body: MyInheritedWidget(
        instance: this,
        child: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    count++;
                  });
                },
                child: Text('count: $count'),
              ),
              const _ChildWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildWidget extends StatelessWidget {
  const _ChildWidget();

  @override
  Widget build(BuildContext context) {
    var instance = MyData.of(context);
    return ElevatedButton(
      onPressed: () {
        instance?.increment();
      },
      child: Text('上一个页面的count: ${instance?.count}'),
    );
  }
}
