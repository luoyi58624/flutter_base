part of flutter_base;

/// 底部导航栏类型
enum BottomNavType {
  material2,
  material3,
  cupertino,
  custom,
}

/// 选项卡式导航栏脚手架控制器
class TabScaffoldController extends GetxController {
  TabScaffoldController({required BottomNavType bottomNavType, double? bottomNavHeight}) {
    this.bottomNavType = bottomNavType.obs;
    _bottomNavHeight = bottomNavHeight;
    tabbarAnimationHeight = _getBottomNavHeight().obs;
  }

  /// 通过静态变量直接获取控制器实例
  static TabScaffoldController get of => Get.find();

  /// 应用的底部导航栏类型
  late Rx<BottomNavType> bottomNavType;

  /// 用户自定义的底部导航栏高度
  double? _bottomNavHeight;

  /// 路由过渡中tabbar的高度
  late Rx<double> tabbarAnimationHeight;

  /// 当前是否显示底部导航栏，如果为true，应用会填充一个底部padding，此变量的作用仅限于解决[CupertinoNavigationBar]、[Hero]动画异常bug，
  /// 通过监听路由的[didPush]、[didPop]生命周期函数，预先设置页面底部[Padding]，这样可以解决[Hero]动画异常bug，
  /// 因为页面过渡期间，底部导航栏的高度是不断变化的，导致整个页面高度也发生变化，从而影响到[Hero]动画的执行。
  final _showBottomNav = true.obs;

  /// 底部导航栏高度
  double get bottomNavHeight => _getBottomNavHeight();

  double _getBottomNavHeight() {
    if (_bottomNavHeight != null) return _bottomNavHeight!;
    switch (bottomNavType.value) {
      case BottomNavType.material2:
        return 56;
      case BottomNavType.material3:
        return 80;
      case BottomNavType.cupertino:
        return 50;
      case BottomNavType.custom:
        return 50;
    }
  }
}
