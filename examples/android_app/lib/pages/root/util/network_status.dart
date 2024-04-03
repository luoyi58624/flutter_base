import 'package:flutter_base/flutter_base.dart';

class NetworkStatusTestPage extends StatefulWidget {
  const NetworkStatusTestPage({super.key});

  @override
  State<NetworkStatusTestPage> createState() => _NetworkStatusTestPageState();
}

class _NetworkStatusTestPageState extends State<NetworkStatusTestPage> {
  final controller = Get.put(NetworkController());

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('网络状态测试'),
      ),
      child: buildCenterColumn(
        [
          Obx(() => Text('当前网络状态 - ${controller.networkStatus.value.name}')),
          Obx(() => Text('是否处于wifi环境 - ${controller.isWifi}')),
          Obx(() => Text('是否处于移动流量环境 - ${controller.isMobile}')),
          Obx(() => Text('是否在线 - ${!controller.isOffline}')),
        ],
      ),
    );
  }
}
