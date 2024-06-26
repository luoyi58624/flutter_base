// part of '../../flutter_base.dart';
//
// /// 顶级App组件，注入全局配置信息
// class AppWidget extends InheritedWidget {
//   /// 注入[AppConfigData]全局配置数据
//   AppWidget({
//     super.key,
//     required super.child,
//     AppData? data,
//   }) {
//     this.data = data ?? AppData.defaultData;
//   }
//
//   /// 全局配置数据
//   late final AppData data;
//
//   /// 获取全局配置数据
//   static AppData? maybeOf(BuildContext context) {
//     final AppWidget? result = context.dependOnInheritedWidgetOfExactType<AppWidget>();
//     return result?.data;
//   }
//
//   /// 获取全局配置数据
//   static AppData of(BuildContext context) {
//     final AppData? data = maybeOf(context);
//     assert(data != null, 'No AppWidget found in context');
//     return data!;
//   }
//
//   /// 根据注入的[AppData]，构建 Material 主题数据
//   static ThemeData buildThemeData({
//     AppData? data,
//     Brightness brightness = Brightness.light,
//   }) {
//     data ??= AppData.defaultData;
//     return _buildThemeData(data, brightness);
//   }
//
//   /// 根据注入的[AppData]，构建 Cupertino 主题数据
//   static CupertinoThemeData buildCupertinoThemeData({
//     AppData? data,
//     Brightness brightness = Brightness.light,
//   }) {
//     data ??= AppData.defaultData;
//     return _buildCupertinoThemeData(data, brightness);
//   }
//
//   @override
//   bool updateShouldNotify(AppWidget oldWidget) {
//     return false;
//   }
// }
//
// class AppData {
//   /// 全局配置数据
//   final AppConfigData config;
//
//   AppData({
//     required this.config,
//   });
//
//   static AppData defaultData = AppData(
//     config: AppConfigData(
//       appbarHeight: 50,
//       radius: 8,
//     ),
//   );
//
//   /// Material2 默认配置，和原生样式基本一致
//   static AppData m2Data = AppData(
//     config: AppConfigData(
//       useMaterial3: false,
//       appbarHeight: 56,
//       appbarElevation: 4,
//       appbarScrollElevation: 4,
//       centerTitle: false,
//       radius: 6,
//       translucenceStatusBar: true,
//     ),
//     theme: AppThemeData(primary: Colors.blue, cardElevation: 2, modalElevation: 4),
//     darkTheme: AppThemeData.dark(primary: Colors.blue),
//   );
//
//   /// Material2 扁平化配置
//   static AppData m2FlatData = AppData(
//     config: AppConfigData(
//       useMaterial3: false,
//       appbarHeight: 56,
//       appbarScrollElevation: 1,
//       radius: 8,
//       buttonRadius: 6,
//     ),
//     theme: AppThemeData(headerColor: Colors.white, cardElevation: 1, modalElevation: 2),
//     darkTheme: AppThemeData.dark(primary: Colors.blue),
//   );
//
//   /// Material3 默认配置，和原生样式基本一致
//   static AppData m3Data = AppData(
//     config: AppConfigData(
//       useMaterial3: true,
//       appbarHeight: 50,
//       appbarElevation: 0,
//       appbarScrollElevation: 4,
//       centerTitle: false,
//       radius: 12,
//     ),
//     theme: AppThemeData(headerColor: Colors.white, cardElevation: 1, modalElevation: 2),
//     darkTheme: AppThemeData.darkTheme,
//   );
//
//   /// Material3 扁平化配置
//   static AppData m3FlatData = AppData(
//     config: AppConfigData(
//       useMaterial3: true,
//       appbarHeight: 50,
//       radius: 8,
//     ),
//     theme: AppThemeData(headerColor: Colors.white),
//     darkTheme: AppThemeData.darkTheme,
//   );
// }
