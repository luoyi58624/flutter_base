part of flutter_base;

/// 底部导航栏控制器，当你使用[createRootPage]函数创建包含多个一级页面的app时，将会注入构造器，
/// 你可以在任何地方通过[BottomNavigationController.of]直接获取它的实例。
// class RootPageController extends GetxController {
//   static RootPageController get of => Get.find();
//
//   final tabIndex = 0.obs;
//   final List<RouterModel> _rootPages;
//
//   /// 底部导航徽标，key-路由path，value-徽标数值
//   final badge = useLocalMapObs<int>({}, 'bottom_navigation_badge');
//
//   RootPageController._(this._rootPages) {
//     for (var page in _rootPages) {
//       if (badge[page.path] == null) {
//         badge[page.path] = 0;
//       }
//     }
//   }
//
//   /// 设置徽标数字
//   void setBadge(String path, int badgeNum) {
//     badge.update(path, (value) => badgeNum);
//   }
//
//   /// 徽标数字增加指定数值
//   void addBadge(String path, int badgeNum) {
//     badge.update(path, (value) => value + badgeNum);
//   }
//
//   /// 徽标数字减少指定数值
//   void subtractBadge(String path, int badgeNum) {
//     badge.update(path, (value) => value - badgeNum);
//   }
//
//   /// 清除徽标
//   void clearBadge(String path) {
//     badge.update(path, (value) => 0);
//   }
// }
//
// class RootPage extends StatefulWidget {
//   const RootPage({
//     super.key,
//     required this.pages,
//   });
//
//   /// 导航页面数组，必须至少包含2个页面
//   final List<RouterModel> pages;
//
//   @override
//   State<RootPage> createState() => _RootPageState();
// }
//
// class _RootPageState extends State<RootPage> {
//   late final RootPageController controller = Get.put(RootPageController._(widget.pages));
//
//   @override
//   Widget build(BuildContext context) {
//     return ExitInterceptWidget(
//       child: Obx(() {
//         return Scaffold(
//           body: IndexedStack(
//             index: controller.tabIndex.value,
//             children: widget.pages.map((e) => e.page).toList(),
//           ),
//           bottomNavigationBar: BottomNavigationBar(
//             onTap: (int index) {
//               setState(() {
//                 controller.tabIndex.value = index;
//               });
//             },
//             currentIndex: controller.tabIndex.value,
//             unselectedFontSize: 12,
//             selectedFontSize: 12,
//             iconSize: 26,
//             unselectedLabelStyle: TextStyle(
//               fontWeight: appTheme.defaultFontWeight,
//             ),
//             selectedItemColor: appTheme.primaryColor,
//             selectedLabelStyle: const TextStyle(
//               fontWeight: FontWeight.bold,
//             ),
//             type: BottomNavigationBarType.fixed,
//             items: widget.pages
//                 .map((e) => BottomNavigationBarItem(
//                       icon: Obx(
//                         () => BadgeWidget(
//                           bagde: controller.badge.value[e.path],
//                           child: Icon(e.icon),
//                         ),
//                       ),
//                       label: e.title,
//                     ))
//                 .toList(),
//           ),
//         );
//       }),
//     );
//   }
// }

// class CupertinoRootPage extends StatefulWidget {
//   const CupertinoRootPage({
//     super.key,
//     required this.pages,
//     this.activeColor,
//     this.inactiveColor = const Color(0xFF666666),
//   });
//
//   final List<NavPageModel> pages;
//
//   /// 激活颜色
//   final Color? activeColor;
//
//   /// 未激活颜色
//   final Color inactiveColor;
//
//   @override
//   State<CupertinoRootPage> createState() => _CupertinoRootPageState();
// }
//
// class _CupertinoRootPageState extends State<CupertinoRootPage> {
//   @override
//   Widget build(BuildContext context) {
//     return ExitInterceptWidget(
//       child: CupertinoTabScaffold(
//         tabBuilder: (BuildContext context, int index) {
//           return CupertinoTabView(builder: (BuildContext context) {
//             return widget.pages[index].page;
//           });
//         },
//         tabBar: CupertinoTabBar(
//           border: const Border(),
//           height: 50,
//           iconSize: 22,
//           inactiveColor: widget.inactiveColor,
//           items: widget.pages
//               .map((e) => BottomNavigationBarItem(
//                     icon: Icon(e.icon),
//                     label: e.title,
//                   ))
//               .toList(),
//         ),
//       ),
//     );
//   }
// }
