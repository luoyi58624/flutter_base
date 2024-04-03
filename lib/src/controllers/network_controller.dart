part of flutter_base;

/// 网络监听控制器，注意：根据插件描述，它无法用于检测用户是否真正地连接到网络，例如用户连接的可能是没有网络访问权限的wifi
class NetworkController extends GetxController {
  static NetworkController get of => Get.find();

  final Connectivity connectivity = Connectivity();

  /// 用户设备当前网络连接状态
  Rx<ConnectivityResult> networkStatus = ConnectivityResult.none.obs;

  /// 用户是否处于wifi环境
  bool get isWifi => networkStatus.value == ConnectivityResult.wifi;

  /// 用户是否在使用移动流量
  bool get isMobile => networkStatus.value == ConnectivityResult.mobile;

  /// 用户是否处于离线状态
  bool get isOffline => networkStatus.value == ConnectivityResult.none;

  /// 用户是否处于在线状态
  bool get isOnline => !isOffline;

  /// 网络变化监听器
  late StreamSubscription<ConnectivityResult> _networkListen;

  /// app活动状态监听器
  late AppLifecycleListener _appLifecycleListener;

  NetworkController() {
    setNetworkStatus();
  }

  /// 注册网络变化回调函数，注意销毁
  Worker listen(void Function(ConnectivityResult) fun) {
    return ever(networkStatus, (value) => fun(value));
  }

  void setNetworkStatus() {
    connectivity.checkConnectivity().then((value) {
      networkStatus.value = value;
    });
  }

  @override
  void onReady() {
    super.onReady();
    _networkListen = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      networkStatus.value = result;
    });
    _appLifecycleListener = AppLifecycleListener(
      // 当应用从后台进入前台时，检查一次网络状态
      onResume: () {
        setNetworkStatus();
      },
    );
  }

  @override
  void onClose() {
    super.onClose();
    _networkListen.cancel();
    _appLifecycleListener.dispose();
  }
}
