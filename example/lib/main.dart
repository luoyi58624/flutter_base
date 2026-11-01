import 'package:example/src/layout/index.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) => ElMobileTheme(
        brightness: GlobalState.isDark.value ? Brightness.dark : Brightness.light,
        child: ObsBuilder(
          builder: (context) {
            final theme = ElView.of(context).themeMode;
            return MaterialApp(
              themeAnimationDuration: theme.duration!,
              themeAnimationCurve: theme.curve!,
              showPerformanceOverlay: GlobalState.showPerformanceOverlay.value,
              debugShowCheckedModeBanner: GlobalState.debugShowCheckedModeBanner.value,
              theme: context.elMaterialThemeData,
              home: AppLayout(),
            );
          },
        ),
      ),
    );
  }
}
