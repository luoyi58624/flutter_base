import 'package:flutter_base/flutter.dart';

class GlobalState{
  const GlobalState._();

  static final isDark = Obs(false);
  static final boottomTabbarIndex = Obs(0);
  static final showPerformanceOverlay = Obs(false);
  static final debugShowCheckedModeBanner = Obs(true);
}
