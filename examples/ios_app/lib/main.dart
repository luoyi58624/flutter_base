import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => RootPage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        )
      ],
    ),
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
  ],
);

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // return MaterialApp.router(
    //   routerConfig: router,
    // );
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    bool flag = false;
    return WillPopScope(
      onWillPop: () async {
        if (flag) {
          return true;
        } else {
          flag = true;
          print('请再按一次返回');
          Future.delayed(Duration(seconds: 2), () {
            flag = false;
          });
          return false;
        }
      },
      child: Scaffold(
        body: navigationShell,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool flag = false;
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: flag,
      onPopInvoked: (_) {
        if (_) {
          return;
        } else {
          setState(() {
            flag = true;
          });
          print('请再按一次返回');
          Future.delayed(Duration(seconds: 2), () {
            setState(() {
              flag = false;
            });
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('首页'),
        ),
        body: Container(),
      ),
    );
  }
}
