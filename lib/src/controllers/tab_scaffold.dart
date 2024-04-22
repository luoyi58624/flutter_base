part of flutter_base;

/// 底部导航栏类型
enum TabbarType {
  material2,
  material3,
  cupertino,
  custom,
}

/// 选项卡式导航栏脚手架控制器
class TabScaffoldController extends GetxController {
  TabScaffoldController({
    required List<UrlNavModel> pages,
    TabbarType? tabbarType,
    double? bottomNavHeight,
  }) {
    this.pages = useLocalListObs(
      pages,
      'tab_pages',
      serializeFun: (model) => jsonEncode(model.toJson()),
      deserializeFun: (json) => UrlNavModel.fromJson(jsonDecode(json)),
    );
    for (var page in this.pages) {
      if (tabBadge[page.path] == null) {
        tabBadge[page.path] = '';
      }
    }
    this.tabbarType = (tabbarType ?? TabbarType.material2).obs;
    _bottomNavHeight = bottomNavHeight;
    this.bottomNavHeight = _getTabHeight();
    _tabbarAnimationHeight = _getTabHeight().obs;
  }

  /// 通过静态变量直接获取控制器实例
  static TabScaffoldController get of => Get.find();

  late RxList<UrlNavModel> pages;

  /// 应用的底部导航栏类型
  late Rx<TabbarType> tabbarType;

  /// 用户自定义的底部导航栏高度
  double? _bottomNavHeight;

  /// 路由过渡中tabbar的高度
  late Rx<double> _tabbarAnimationHeight;

  final demoList = [1, 2, 3].obs;

  /// 当前是否显示底部导航栏，如果为true，应用会填充一个底部padding，此变量的作用仅限于解决[CupertinoNavigationBar]、[Hero]动画异常bug，
  /// 通过监听路由的[didPush]、[didPop]生命周期函数，预先设置页面底部[Padding]，这样可以解决[Hero]动画异常bug，
  /// 因为页面过渡期间，底部导航栏的高度是不断变化的，导致整个页面高度也发生变化，从而影响到[Hero]动画的执行。
  final _showBottomNav = true.obs;

  /// 底部导航栏高度
  late double bottomNavHeight;

  final tabBadge = useLocalMapObs<String>({}, 'bottom_nav_badge');

  /// 设置徽标
  /// * index tab索引
  /// * badge 徽标内容，可以是数字，也可以是字符串
  void setTabBadge(int index, dynamic badge) {
    tabBadge.update(pages[index].path, (v) => badge.toString());
  }

  /// 徽标数字增加指定数值
  /// * index tab索引
  /// * num 增加的数值，如果之前徽标是字符，那么会自动转成数字
  void addTabBadge(int index, int num) {
    tabBadge.update(pages[index].path, (v) => (DartUtil.safeInt(v) + num).toString());
  }

  /// 徽标数字减少指定数值
  /// * index tab索引
  /// * num 减少的数值，如果之前徽标是字符，那么会自动转成数字
  void subTabBadge(int index, int num) {
    tabBadge.update(pages[index].path, (v) => (DartUtil.safeInt(v) - num).toString());
  }

  /// 清除徽标
  /// * index tab索引，如果为null则清空所有
  void clearTabBadge(int? index) {
    if (index == null) {
      for (var page in pages) {
        tabBadge.update(page.path, (value) => '');
      }
    } else {
      tabBadge.update(pages[index].path, (v) => '');
    }
  }

  double _getTabHeight() {
    if (_bottomNavHeight == null) {
      switch (tabbarType.value) {
        case TabbarType.material2:
          return 56;
        case TabbarType.material3:
          return 80;
        case TabbarType.cupertino:
          return 50;
        case TabbarType.custom:
          return 50;
      }
    } else {
      return _bottomNavHeight!;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(tabbarType, (v) {
      bottomNavHeight = _getTabHeight();
    });
  }
}
