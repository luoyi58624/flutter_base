// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/pages/home/showcase/panel.dart';
import 'home_showcase_test.dart' as fixture;

Finder _button(String label) => find.byWidgetPredicate((w) => w is ElButton && w.child == label);

void main() {
  setUpAll(fixture.loadShowcaseFonts);

  for (final single in [false, true]) {
    testWidgets('首页${single ? '单按钮提醒' : '双按钮危险确认'}使用通栏操作区并保留返回值', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final boundary = GlobalKey();
      Future<bool?>? result;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ElComponentProvider(
              components: el.mobileComponents,
              // 使用首页字体与覆写色，同时验证弹层保留调用位置的主题。
              style: ElStyle(
                fontFamily: 'Roboto',
                vars: {ElTokens.$primary: Color(0xff2454c6), ElTokens.$error: Color(0xffb5283c)},
              ),
              child: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: ElButton(
                      child: '打开',
                      onPressed: () => result = demoDialog(
                        context,
                        title: single ? '内容已经同步' : '删除这条收藏？',
                        message: single ? '你可以在其他设备上继续查看。' : '删除后将从当前列表中移除。',
                        confirm: single ? '知道了' : '确认删除',
                        single: single,
                        danger: !single,
                        placement: single ? .center : .bottom,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(_button('打开'));
      await tester.pumpAndSettle();
      final dialog = tester.getRect(find.byType(ElDialog));
      final confirm = _button(single ? '知道了' : '确认删除');
      final action = tester.getRect(confirm);
      expect(action.height, 66);
      expect(action.bottom, dialog.bottom);
      expect(action.right, dialog.right);
      expect(action.width, dialog.width / (single ? 1 : 2));
      final theme = tester.element(confirm).elTheme;
      final render = tester.renderObject<ElRenderView>(
        find.descendant(of: confirm, matching: find.byType(ElView)).first,
      );
      expect(render.committedResolvedStyle.box.backgroundColor?.a ?? 0, 0);
      expect(render.committedResolvedStyle.inheritedText.color, single ? theme.primary : theme.error);
      if (single) {
        expect(_button('取消'), findsNothing);
      } else {
        final cancel = tester.getRect(_button('取消'));
        expect(cancel.left, dialog.left);
        expect(cancel.right, action.left);
        expect(cancel.size, action.size);
        final divider = find.descendant(
          of: find.byType(ElDialog),
          matching: find.byWidgetPredicate((w) => w is ElView && w.style?.width == 1 && w.style?.height == 20),
        );
        expect(tester.getRect(divider).center.dx, dialog.center.dx);
        expect(tester.getRect(divider).top, action.top + 20);
      }

      final capture = Platform.environment['DIALOG_SCREENSHOTS'];
      if (capture != null) {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$capture/${single ? 'single' : 'paired'}.png').writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      // 原先按钮外的底部留白也必须能确认，避免只有文字附近响应点击。
      await tester.tapAt(Offset(action.center.dx, action.bottom - 3));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.byType(ElDialog), findsNothing);
      if (!single) {
        await tester.tap(_button('打开'));
        await tester.pumpAndSettle();
        final cancel = tester.getRect(_button('取消'));
        await tester.tapAt(Offset(cancel.center.dx, cancel.bottom - 3));
        await tester.pumpAndSettle();
        expect(await result, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
