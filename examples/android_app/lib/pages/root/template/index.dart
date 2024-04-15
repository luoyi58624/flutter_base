import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'child.dart';
import 'sliver.dart';

class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key});

  @override
  State<TemplatePage> createState() => TemplatePageState();
}

class TemplatePageState extends State<TemplatePage> {
  int count = 0;

  void addCount() {
    setState(() {
      count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模板列表'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: fontDemo,
          )
        ],
      ),
    );
  }

  Widget get fontDemo => buildCenterColumn([
        IconButton(onPressed: () {}, icon: const Icon(Icons.ac_unit)),
        ElevatedButton(
          onPressed: () {
            RouterUtil.push(context, const SliverTestPage());
          },
          child: const Text('Sliver'),
        ),
        const SizedBox(height: 8),
        Hero(
          tag: 'button',
          child: GestureDetector(
            onTap: () {
              RouterUtil.push(context, const _HeroChildPage(), rootNavigator: true);
            },
            child: Container(
              width: 100,
              height: 100,
              color: Colors.grey,
            ),
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w100,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w200,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w300,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w400,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          '西那卡塞吸机你显卡xanjsxnkjasnxkjansxk行啊就开心阿珂',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ]);
}

class _HeroChildPage extends StatelessWidget {
  const _HeroChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero动画子页面'),
      ),
      body: Container(
        child: Hero(
          tag: 'button',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      ),
    );
  }
}
