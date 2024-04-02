import 'package:flutter_base/flutter_base.dart';

import 'pages/home.dart';
import 'pages/second.dart';

var router = FlutterRouter(routes: [
// GoRoute(path: '/', builder: (context, state) => const HomePage()),
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => MaterialRootPage(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/second',
            builder: (context, state) => const SecondPage(),
          ),
        ],
      ),
    ],
  ),
]);
