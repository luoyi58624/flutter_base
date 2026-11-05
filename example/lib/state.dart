import 'package:flutter_base/flutter.dart';

class GlobalState {
  const GlobalState._();

  static final isDark = Obs(false);
  static final showPerformanceOverlay = Obs(false);
  static final debugShowCheckedModeBanner = Obs(true);
}
