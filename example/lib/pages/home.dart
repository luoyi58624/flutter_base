import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  count++;
                });
              },
              child: Text('count：$count'),
            ),
            ElevatedButton(
              onPressed: () {
                router.push(const ChildPage2(), context: context);
              },
              child: const Text('Hello World!'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/child');
              },
              child: const Text('base包的子页面 - go'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/child2');
              },
              child: const Text('child - go'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/animation');
              },
              child: const Text('动画页面 - go'),
            ),
            ElevatedButton(
              onPressed: () {
                ToastUtil.showToast('hello');
              },
              child: const Text('toast'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChildPage2 extends StatelessWidget {
  const ChildPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('子页面2'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                router.push(const ChildPage2(), context: context);
              },
              child: const Text('Hello World!'),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/child/second');
              },
              child: const Text('二级页面 - go'),
            ),
          ],
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二级页面'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            router.push(const SecondPage());
          },
          child: const Text('二级页面'),
        ),
      ),
    );
  }
}

class AnimationPage extends StatelessWidget {
  const AnimationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动画页面'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            context.pop();
          },
          child: const Text('返回'),
        ),
      ),
    );
  }
}