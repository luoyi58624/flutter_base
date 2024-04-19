import 'dart:math';
import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'controller.dart';

class GetxUtilPage extends StatelessWidget {
  const GetxUtilPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.isLogEnable = false;
    final controller = Get.put(GetxUtilController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Getx工具类测试'),
      ),
      body: buildCenterColumn([
        Obx(
          () => ElevatedButton(
            onPressed: () {
              controller.count.value++;
            },
            child: Text('count: ${controller.count.value} - ${controller.xx.value}'),
          ),
        ),
        Obx(
          () => ElevatedButton(
            onPressed: () {
              controller.userModel.value = UserModel.fromJson({
                'username': faker.person.firstName(),
                'password': Random().nextInt(100000),
              });
            },
            child: Text(controller.userModel.value.toString()),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            context.push(const _ListPage());
          },
          child: const Text('响应式缓存列表页面'),
        ),
        ElevatedButton(
          onPressed: () {
            context.push(const _ListPage2());
          },
          child: const Text('普通列表页面'),
        ),
      ]),
    );
  }
}

class _ListPage extends StatefulWidget {
  const _ListPage();

  @override
  State<_ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<_ListPage> {
  final GetxUtilController controller = Get.find();
  final ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('响应式缓存列表'),
        actions: [
          IconButton(
            onPressed: () {
              controller.userList.clear();
            },
            icon: const Icon(Icons.clear),
          ),
          IconButton(
            onPressed: () {
              int length = controller.userList.length;
              for (int i = length; i < length + 100000; i++) {
                controller.userList.add({
                  'userId': i + 1,
                  'username': faker.person.firstName(),
                  'height': Random().nextInt(150) + 50,
                  'image': faker.image.image(random: true),
                });
              }
              // List<Map<String, dynamic>> userList = [];
              // for (int i = length; i < length + 500; i++) {
              //   userList.add({
              //     'userId': i + 1,
              //     'username': faker.person.firstName(),
              //   });
              // }
              // controller.userList.addAll(userList);
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Obx(() {
        i('list build');
        return buildCupertinoScrollbar(
          controller: scrollController,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SuperSliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(
                    height: DartUtil.safeDouble(controller.userList[index]['height']),
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ImageWidget(
                          url: controller.userList[index]['image'],
                        ),
                        Text('${controller.userList[index]['userId']} - ${controller.userList[index]['username']} '),
                      ],
                    ),
                  ),
                  childCount: controller.userList.length,
                ),
              )
            ],
          ),
        );
      }),
    );
  }
}

class _ListPage2 extends StatefulWidget {
  const _ListPage2();

  @override
  State<_ListPage2> createState() => _ListPage2State();
}

class _ListPage2State extends State<_ListPage2> {
  final ScrollController scrollController = ScrollController();
  List<Map<String, dynamic>> userList = [];
  bool enableItemExtent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('列表2'),
        actions: [
          Switch(
            value: enableItemExtent,
            onChanged: (value) {
              setState(() {
                enableItemExtent = value;
              });
            },
          ),
          IconButton(
            onPressed: () {
              userList.clear();
              setState(() {});
            },
            icon: const Icon(Icons.clear),
          ),
          IconButton(
            onPressed: () {
              int length = userList.length;
              for (int i = length; i < length + 1000; i++) {
                userList.add({
                  'userId': i + 1,
                  'username': faker.person.firstName(),
                  'height': Random().nextInt(150) + 30,
                });
              }
              setState(() {});
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: buildCupertinoScrollbar(
        controller: scrollController,
        child: ListView.builder(
          controller: scrollController,
          itemCount: userList.length,
          // itemExtent: enableItemExtent ? 56 : null,
          itemExtentBuilder: enableItemExtent ? (index, _) => DartUtil.safeDouble(userList[index]['height']) : null,
          itemBuilder: (context, index) => Container(
            height: DartUtil.safeDouble(userList[index]['height']),
            color: Colors.grey.shade100,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${userList[index]['userId']} - ${userList[index]['username']} '),
          ),
        ),
      ),
    );
  }
}
