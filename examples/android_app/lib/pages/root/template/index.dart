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
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text(
              '模板列表',
            ),
          ),
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
