import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'artwork.dart';

const effectInk = Color(0xff1c1c1e);
const effectMuted = Color(0xff797980);
const effectBlue = Color(0xff007aff);
const effectCanvas = Color(0xfff2f2f7);
const effectWhite = Color(0xfffafaf8);

Future<void> effectRefresh() => Future<void>.delayed(Duration(milliseconds: 600));

/// 保留旧示例的阅读宽度、组块间距、正文底色与下拉刷新。
Widget effectPage(
  BuildContext context, {
  required String title,
  required List<Widget> slivers,
  Color background = effectCanvas,
  Widget? leading,
  List<Widget>? actions,
  Widget? bottomNavigationBar,
  bool refresh = true,
}) => Scaffold(
  backgroundColor: background,
  appBar: AppBar(
    title: Text(title),
    centerTitle: false,
    backgroundColor: background,
    surfaceTintColor: Colors.transparent,
    leading: leading,
    actions: actions,
    shape: Border(bottom: BorderSide(color: Color(0xffdedee3), width: .5)),
  ),
  bottomNavigationBar: bottomNavigationBar,
  body: SafeArea(
    top: false,
    child: refresh
        ? ElRefresh(
            onRefresh: effectRefresh,
            child: ElScroll.sliver(slivers: slivers),
          )
        : ElScroll.sliver(slivers: slivers),
  ),
);

Widget effectContent(Widget child, {EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 20)}) => Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 680),
    child: Padding(padding: padding, child: child),
  ),
);

Widget effectSectionLabel(String label, {String? trailing}) => effectContent(
  Padding(
    padding: EdgeInsets.only(top: 28, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, color: effectMuted)),
        ),
        ?(trailing == null ? null : Text(trailing, style: TextStyle(fontSize: 12, color: effectMuted))),
      ],
    ),
  ),
);

Widget effectGroup(List<Widget> children) => effectContent(
  Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  ),
  padding: EdgeInsets.symmetric(horizontal: 16),
);

Widget effectAvatar(String label, Color color, {double size = 42}) => CircleAvatar(
  radius: size / 2,
  backgroundColor: color.withValues(alpha: .12),
  foregroundColor: color,
  child: Text(
    label,
    style: TextStyle(fontWeight: FontWeight.w600, fontSize: size * .38),
  ),
);

Widget effectParagraph(String paragraph) => Padding(
  padding: EdgeInsets.only(bottom: 20),
  child: Text(paragraph, style: TextStyle(fontSize: 17, height: 1.8, color: Color(0xff414146))),
);

Widget effectHairline() => Divider(height: .5, thickness: .5, color: Color(0xffdedee3));

Widget effectNavigationBar(
  BuildContext context,
  String label, {
  Widget? action,
  double opacity = 1,
  Color background = effectWhite,
}) => Container(
  color: background,
  height: 56,
  child: Row(
    children: [
      IconButton(tooltip: '返回', onPressed: () => Navigator.maybePop(context), icon: Icon(Icons.chevron_left)),
      Expanded(
        child: Opacity(
          opacity: opacity,
          child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      ),
      ?action,
    ],
  ),
);

Widget effectLandscape(int variant, {double height = 230, BorderRadius? radius}) => ClipRRect(
  borderRadius: radius ?? BorderRadius.circular(4),
  child: SizedBox(
    height: height,
    width: double.infinity,
    child: LandscapeArtwork(variant: variant),
  ),
);

/// 各页面使用 SliverList/SliverToBoxAdapter 自行组合，不把导航状态交给正文。
Widget effectSliverItems(List<Widget> children) =>
    SliverList(delegate: SliverChildListDelegate(children, addAutomaticKeepAlives: false));

Widget effectDescription(String title, String subtitle) => effectContent(
  Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.6)),
        SizedBox(height: 10),
        Text(subtitle, style: TextStyle(fontSize: 15, height: 1.6, color: effectMuted)),
      ],
    ),
  ),
);
