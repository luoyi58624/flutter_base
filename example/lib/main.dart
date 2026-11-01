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
        brightness: GlobalState.isDark.value == 1 ? Brightness.dark : Brightness.light,
        child: Builder(
          builder: (context) => MaterialApp(theme: context.elMaterialThemeData, home: AppLayout()),
        ),
      ),
    );
  }
}
