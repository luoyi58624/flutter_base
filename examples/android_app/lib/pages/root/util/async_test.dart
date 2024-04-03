import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class AsyncTestPage extends StatefulWidget {
  const AsyncTestPage({super.key});

  @override
  State<AsyncTestPage> createState() => _AsyncTestPageState();
}

class _AsyncTestPageState extends State<AsyncTestPage> {
  int count = 0;

  late GestureTapCallback throttleFun = AsyncUtil.throttle(() {
    setState(() {
      count++;
    });
  }, 1000);

  late GestureTapCallback debounceFun = AsyncUtil.debounce(() {
    setState(() {
      count++;
    });
  }, 1000);

  late GestureTapCallback debounceFun2 = AsyncUtil.debounce(() {
    setState(() {
      count++;
    });
  }, 1000, true);

  @override
  void initState() {
    super.initState();
    FlutterUtil.nextTick(() async {
      // 在initState中显示loading必须等待页面build完成后才能调用
      LoadingUtil.show('加载中');
      // 延迟300毫米关闭loading
      AsyncUtil.delayed(() {
        LoadingUtil.close();
      }, 300);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异步函数测试'),
      ),
      body: buildCenterColumn([
        const Text('节流 - 在一定时间内忽略多次点击事件'),
        ElevatedButton(
          onPressed: throttleFun,
          child: Text(
            '节流 - count: $count',
          ),
        ),
        const Text('防抖 - 延迟指定时间执行逻辑，再次执行将重置延迟时间'),
        ElevatedButton(
          onPressed: debounceFun,
          child: Text(
            '防抖 - count: $count',
          ),
        ),
        const Text('防抖，立即执行一次'),
        ElevatedButton(
          onPressed: debounceFun2,
          child: Text(
            '防抖 - count: $count',
          ),
        ),
      ]),
    );
  }
}
