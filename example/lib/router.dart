import 'package:flutter_base/flutter_base.dart';

import 'pages/home.dart';

void createRouter() {
  router = FlutterRouter(
    routes: [
      // GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'child2',
            // builder: (context, state) => const ChildPage(),
            pageBuilder: (context, state) => CustomSlideTransition(child: const ChildPage2()),
            routes: [
              GoRoute(path: 'second', builder: (context, state) => const SecondPage()),
            ],
          ),
          GoRoute(
            path: 'animation',
            pageBuilder: FlutterRouter.pageBuilder(const AnimationPage()),
          ),
        ],
      ),
      GoRoute(
        path: '/child',
        pageBuilder: FlutterRouter.pageBuilder(const ChildPage(
          title: '子页面',
        )),
      ),
    ],
  );
}
