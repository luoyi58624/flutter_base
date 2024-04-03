import 'package:flutter/material.dart';

class SliverTestPage extends StatelessWidget {
  const SliverTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sliver测试'),
      ),
      body: Scrollbar(
        child: CustomScrollView(
          slivers: [
            SliverList.builder(
              itemCount: 20,
              itemBuilder: (context, index) => ListTile(
                title: Text('列表-${index + 1}'),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                width: 100,
                height: 100,
                color: Colors.grey,
              ),
            ),
            SliverList.builder(
              itemCount: 20,
              itemBuilder: (context, index) => ListTile(
                title: Text('列表-${index + 1}'),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                width: 100,
                height: 100,
                color: Colors.grey,
              ),
            ),
            SliverList.builder(
              itemCount: 20,
              itemBuilder: (context, index) => ListTile(
                title: Text('列表-${index + 1}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
