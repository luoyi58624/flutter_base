import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:example/global.dart';

class RoutePage extends HookWidget {
  const RoutePage({
    super.key,
    this.isChild = false,
  });

  final bool isChild;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('路由动画测试${isChild ? ': 子页面' : ''}'),
      ),
      body: buildScrollWidget(
        child: Column(
          children: [
            buildCardWidget(context, children: [
              buildCellWidget(context, title: '默认动画', onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChildPage()));
              }),
              buildCellWidget(context, title: 'IOS动画', onTap: () {
                Navigator.of(context).push(CupertinoPageRoute(builder: (context) => const ChildPage()));
              }),
              buildCellWidget(context, title: 'MyRoutePage动画', onTap: () {
                Navigator.of(context).push(MyRoutePage(builder: (context) => const RoutePage(isChild: true)));
              }),
              buildCellWidget(context, title: 'MyIosRoutePage动画', onTap: () {
                Navigator.of(context).push(MyIosRoutePage(builder: (context) => const ChildPage()));
              }),
              buildCellWidget(context, title: '无动画', onTap: () {
                Navigator.of(context).push(PageRouteBuilder(
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (context, _, __) {
                    return const ChildPage();
                  },
                ));
              }),
              buildCellWidget(context, title: 'Fade渐变动画', onTap: () {
                Navigator.of(context).push(PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) {
                  return FadeTransition(opacity: animation, child: const ChildPage());
                }));
              }),
              buildCellWidget(context, title: 'Fade渐变动画', onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const ChildPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  ),
                );
              }),
            ]),
          ],
        ),
      ),
    );
  }
}

class ChildPage extends StatelessWidget {
  const ChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('子页面'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('返回'),
        ),
      ),
    );
  }
}

class MyIosRoutePage extends CupertinoPageRoute {
  MyIosRoutePage({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  bool get popGestureEnabled => false;
}

class MyRoutePage<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  MyRoutePage({
    super.settings,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
    required this.builder,
  });

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(scopesRoute: true, explicitChildNodes: true, child: builder(context));
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // final Animatable<Offset> kRightMiddleTween = Tween<Offset>(
    //   begin: const Offset(0.2, 0.0),
    //   end: Offset.zero,
    // );
    //
    // final Animatable<Offset> kMiddleLeftTween = Tween<Offset>(
    //   begin: Offset.zero,
    //   end: const Offset(-0.1, 0.0),
    // );
    //
    // var primaryPositionAnimation = CurvedAnimation(
    //   parent: animation,
    //   curve: Curves.easeOut,
    //   reverseCurve: Curves.easeOut,
    // ).drive(kRightMiddleTween);
    //
    // var secondPositionAnimation = CurvedAnimation(
    //   parent: secondaryAnimation,
    //   curve: Curves.easeOut,
    //   reverseCurve: Curves.easeOut,
    // ).drive(kMiddleLeftTween);
    // return SlideTransition(
    //   position: secondPositionAnimation,
    //   transformHitTests: false,
    //   child: SlideTransition(
    //     position: primaryPositionAnimation,
    //     child: child,
    //   ),
    // );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.25),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
    // const begin = Offset(0.3, 0.0);
    // const end = Offset.zero;
    // const curve = Curves.ease;
    // final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    // final offsetAnimation = animation.drive(tween);
    // return FadeTransition(
    //   opacity: animation,
    //   child: SlideTransition(
    //     position: offsetAnimation,
    //     child: child,
    //   ),
    // );
    // return FadeTransition(
    //   opacity: animation,
    //   child: SlideTransition(
    //     position: Tween<Offset>(
    //       begin: const Offset(0.2, 0.0),
    //       end: Offset.zero,
    //     ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
    //     child: SlideTransition(
    //       position: Tween<Offset>(
    //         begin: Offset.zero,
    //         end: const Offset(-0.2, 0.0),
    //       ).chain(CurveTween(curve: Curves.easeOut)).animate(secondaryAnimation),
    //       child: child,
    //     ),
    //   ),
    // );
  }
}
