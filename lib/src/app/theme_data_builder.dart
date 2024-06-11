// part of '../../flutter_base.dart';
//
// ThemeData _buildThemeData(AppData appData, Brightness brightness) {
//   bool isDarkMode = brightness == Brightness.dark;
//   final appConfig = appData.config;
//   final lightTheme = appData.theme;
//   final darkTheme = appData.darkTheme;
//   final appTheme = isDarkMode ? darkTheme : lightTheme;
//
//   if (appConfig.translucenceStatusBar) {
//     () {
//       SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 200)));
//     }.delay(200);
//   } else {
//     () {
//       SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 0)));
//     }.delay(200);
//   }
//
//   final buttonBorder = appConfig.buttonRadius != null
//       ? RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(appConfig.buttonRadius!),
//         )
//       : null;
//   final buttonStyle = appConfig.buttonRadius != null
//       ? ButtonStyle(
//           shape: WidgetStatePropertyAll(buttonBorder),
//         )
//       : null;
//
//   final cardBorder = RoundedRectangleBorder(
//     borderRadius: BorderRadius.circular(appConfig.radius),
//   );
//
//   final themeData = ThemeData(
//     useMaterial3: appConfig.useMaterial3,
//     colorScheme: appConfig.useMaterial3
//         ? ColorScheme.fromSeed(brightness: brightness, seedColor: appTheme.primary)
//         : ColorScheme.fromSwatch(brightness: brightness, primarySwatch: appTheme.primary.toMaterialColor()),
//     // 设置全局默认文字主题
//     textTheme: _textTheme(appTheme, appConfig),
//     // 是否禁用波纹
//     splashFactory: appConfig.enableRipple ? InkRipple.splashFactory : noRipperFactory,
//     // 解决web上material按钮外边距为0问题，与移动端的效果保持一致
//     materialTapTargetSize: MaterialTapTargetSize.padded,
//     // 标准显示密度
//     visualDensity: VisualDensity.standard,
//     // 统一页面过渡动画
//     pageTransitionsTheme: const PageTransitionsTheme(builders: {
//       TargetPlatform.android: CupertinoPageTransitionsBuilder(),
//       TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
//       TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
//     }),
//     // 背景颜色
//     scaffoldBackgroundColor: appTheme.bgColor,
//     // 图标颜色
//     iconTheme: IconThemeData(color: appTheme.iconColor),
//   );
//
//   return themeData.copyWith(
//     buttonTheme: ButtonThemeData(shape: buttonBorder),
//     elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
//     textButtonTheme: TextButtonThemeData(style: buttonStyle),
//     filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
//     appBarTheme: AppBarTheme(
//       centerTitle: appConfig.centerTitle,
//       toolbarHeight: appConfig.appbarHeight,
//       elevation: appConfig.appbarElevation,
//       scrolledUnderElevation: appConfig.appbarScrollElevation,
//       backgroundColor: appTheme.headerColor,
//       titleTextStyle: TextStyle(
//         fontFamily: appConfig.fontFamily,
//         fontSize: 18,
//         fontWeight: ElFont.bold,
//         color: appTheme.headerColor.isDark ? darkTheme.textColor : lightTheme.textColor,
//       ),
//       iconTheme: IconThemeData(
//         color: appTheme.headerColor.isDark ? darkTheme.iconColor : lightTheme.iconColor,
//       ),
//     ),
//     tabBarTheme: TabBarTheme(
//       unselectedLabelStyle: TextStyle(
//         fontFamily: appConfig.fontFamily,
//         fontWeight: ElFont.bold,
//         fontSize: 15,
//       ),
//       labelStyle: TextStyle(
//         fontFamily: appConfig.fontFamily,
//         fontWeight: ElFont.bold,
//         fontSize: 15,
//         color: appTheme.primary,
//       ),
//       unselectedLabelColor: appTheme.headerColor.isDark ? darkTheme.textColors[1] : lightTheme.textColor,
//     ),
//     bottomNavigationBarTheme: BottomNavigationBarThemeData(
//       elevation: 2,
//       type: BottomNavigationBarType.fixed,
//       backgroundColor: appTheme.headerColor,
//       unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: ElFont.medium),
//       selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: ElFont.bold, color: appTheme.primary),
//       unselectedIconTheme: const IconThemeData(size: 26),
//       selectedIconTheme: IconThemeData(color: appTheme.primary, size: 26),
//     ),
//     cardTheme: CardTheme(
//       color: appTheme.cardColor,
//       // m3会将此颜色和color进行混合从而产生一个新的material颜色 (生成一个淡淡的Primary Color)，
//       // 这里将其重置为透明，表示卡片用默认color展示
//       surfaceTintColor: Colors.transparent,
//       elevation: appTheme.cardElevation,
//       margin: const EdgeInsets.all(8),
//       shape: cardBorder,
//     ),
//     drawerTheme: DrawerThemeData(
//       backgroundColor: appTheme.modalColor,
//       surfaceTintColor: Colors.transparent,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(0),
//       ),
//     ),
//     listTileTheme: ListTileThemeData(
//       titleTextStyle: TextStyle(
//         fontFamily: appConfig.fontFamily,
//         fontWeight: ElFont.medium,
//         color: appTheme.textColor,
//         fontSize: 15,
//       ),
//       subtitleTextStyle: TextStyle(
//         fontFamily: appConfig.fontFamily,
//         fontWeight: ElFont.normal,
//         color: appTheme.textColors[1],
//         fontSize: 13,
//       ),
//       iconColor: appTheme.iconColor,
//     ),
//     inputDecorationTheme: InputDecorationTheme(
//       // border: const OutlineInputBorder(
//       //   borderSide: BorderSide(color: Colors.grey),
//       // ),
//       labelStyle: TextStyle(fontFamily: appConfig.fontFamily, fontSize: 16, fontWeight: ElFont.medium),
//       hintStyle: TextStyle(fontFamily: appConfig.fontFamily, fontSize: 14, fontWeight: ElFont.medium),
//     ),
//     expansionTileTheme: ExpansionTileThemeData(
//       textColor: appTheme.primary,
//       shape: Border.all(width: 0, style: BorderStyle.none),
//       collapsedShape: Border.all(width: 0, style: BorderStyle.none),
//     ),
//     popupMenuTheme: PopupMenuThemeData(
//       color: appTheme.modalColor,
//       surfaceTintColor: Colors.transparent,
//       elevation: appTheme.modalElevation,
//       enableFeedback: true,
//       textStyle: TextStyle(
//         fontFamily: appConfig.fontFamily,
//         fontWeight: ElFont.normal,
//         color: appTheme.textColor,
//         fontSize: 14,
//       ),
//       shape: cardBorder,
//     ),
//     dialogTheme: DialogTheme(
//       titleTextStyle: TextStyle(
//         color: appTheme.textColor,
//         fontSize: 18,
//         fontWeight: ElFont.bold,
//       ),
//       contentTextStyle: TextStyle(
//         color: appTheme.textColors[2],
//         fontSize: 15,
//         fontWeight: ElFont.normal,
//       ),
//       elevation: appTheme.modalElevation,
//       backgroundColor: appTheme.modalColor,
//       surfaceTintColor: Colors.transparent,
//       shape: cardBorder,
//       actionsPadding: const EdgeInsets.all(8),
//       insetPadding: EdgeInsets.zero,
//     ),
//     progressIndicatorTheme: ProgressIndicatorThemeData(
//       refreshBackgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.white,
//       color: isDarkMode ? Colors.white : appTheme.primary,
//     ),
//     segmentedButtonTheme: const SegmentedButtonThemeData(
//       style: ButtonStyle(
//         shape: WidgetStatePropertyAll(
//           StadiumBorder(side: BorderSide()),
//         ),
//         side: WidgetStatePropertyAll(BorderSide(color: Colors.grey)),
//       ),
//     ),
//   );
// }
//
// CupertinoThemeData _buildCupertinoThemeData(AppData appData, Brightness brightness) {
//   AppThemeData theme = brightness == Brightness.light ? appData.theme : appData.darkTheme;
//   CupertinoThemeData themeData = CupertinoThemeData(brightness: brightness);
//   String? fontFamily = appData.config.fontFamily ?? themeData.textTheme.textStyle.fontFamily;
//
//   return themeData.copyWith(
//     primaryColor: theme.primary,
//     textTheme: CupertinoTextThemeData(
//       textStyle: themeData.textTheme.textStyle.copyWith(
//         fontWeight: ElFont.normal,
//         fontFamily: fontFamily,
//       ),
//       tabLabelTextStyle: themeData.textTheme.tabLabelTextStyle.copyWith(
//         fontSize: 12,
//         fontFamily: fontFamily,
//         fontWeight: ElFont.normal,
//       ),
//       navActionTextStyle: themeData.textTheme.navActionTextStyle.copyWith(
//         color: theme.primary,
//         fontFamily: fontFamily,
//         fontWeight: ElFont.medium,
//         fontSize: 16,
//       ),
//       navTitleTextStyle: themeData.textTheme.navTitleTextStyle.copyWith(
//         fontFamily: fontFamily,
//         fontWeight: ElFont.medium,
//       ),
//       navLargeTitleTextStyle: themeData.textTheme.navLargeTitleTextStyle.copyWith(
//         fontFamily: fontFamily,
//         fontWeight: ElFont.normal,
//       ),
//     ),
//   );
// }
//
// TextTheme _textTheme(AppThemeData theme, AppConfigData config) {
//   return TextTheme(
//     displayLarge: TextStyle(
//       fontWeight: ElFont.bold,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     displayMedium: TextStyle(
//       fontWeight: ElFont.medium,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     displaySmall: TextStyle(
//       fontWeight: ElFont.medium,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     headlineLarge: TextStyle(
//       fontWeight: ElFont.normal,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     headlineMedium: TextStyle(
//       fontWeight: ElFont.normal,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     headlineSmall: TextStyle(
//       fontWeight: ElFont.normal,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     titleLarge: TextStyle(
//       fontWeight: ElFont.bold,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     titleMedium: TextStyle(
//       fontWeight: ElFont.bold,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     titleSmall: TextStyle(
//       fontWeight: ElFont.bold,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     bodyLarge: TextStyle(
//       fontWeight: ElFont.normal,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     bodyMedium: TextStyle(
//       fontWeight: ElFont.normal,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     bodySmall: TextStyle(
//       fontWeight: ElFont.normal,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     labelLarge: TextStyle(
//       fontWeight: ElFont.medium,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     labelMedium: TextStyle(
//       fontWeight: ElFont.medium,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//     labelSmall: TextStyle(
//       fontWeight: ElFont.medium,
//       color: theme.textColor,
//       fontFamily: config.fontFamily,
//       fontFamilyFallback: config.fontFamilyFallback,
//     ),
//   );
// }
