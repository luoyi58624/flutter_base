// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

/// Implements a single iOS application page's layout.
///
/// The scaffold lays out the navigation bar on top and the content between or
/// behind the navigation bar.
///
/// When tapping a status bar at the top of the ExtendedCupertinoPageScaffold, an
/// animation will complete for the current primary [ScrollView], scrolling to
/// the beginning. This is done using the [PrimaryScrollController] that
/// encloses the [ScrollView]. The [ScrollView.primary] flag is used to connect
/// a [ScrollView] to the enclosing [PrimaryScrollController].
///
/// {@tool dartpad}
/// This example shows a [ExtendedCupertinoPageScaffold] with a [ListView] as a [child].
/// The [CupertinoButton] is connected to a callback that increments a counter.
/// The [backgroundColor] can be changed.
///
/// ** See code in examples/api/lib/cupertino/page_scaffold/cupertino_page_scaffold.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [CupertinoTabScaffold], a similar widget for tabbed applications.
///  * [CupertinoPageRoute], a modal page route that typically hosts a
///    [ExtendedCupertinoPageScaffold] with support for iOS-style page transitions.
class ExtendedCupertinoPageScaffold extends StatefulWidget {
  /// Creates a layout for pages with a navigation bar at the top.
  const ExtendedCupertinoPageScaffold({
    super.key,
    this.navigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    required this.child,
  });

  final ObstructingPreferredSizeWidget? navigationBar;

  /// Widget to show in the main content area.
  ///
  /// Content can slide under the [navigationBar] when they're translucent.
  /// In that case, the child's [BuildContext]'s [MediaQuery] will have a
  /// top padding indicating the area of obstructing overlap from the
  /// [navigationBar].
  final Widget child;

  /// The color of the widget that underlies the entire scaffold.
  ///
  /// By default uses [CupertinoTheme]'s `scaffoldBackgroundColor` when null.
  final Color? backgroundColor;

  /// Whether the [child] should size itself to avoid the window's bottom inset.
  ///
  /// For example, if there is an onscreen keyboard displayed above the
  /// scaffold, the body can be resized to avoid overlapping the keyboard, which
  /// prevents widgets inside the body from being obscured by the keyboard.
  ///
  /// Defaults to true.
  final bool resizeToAvoidBottomInset;

  @override
  State<ExtendedCupertinoPageScaffold> createState() => _ExtendedCupertinoPageScaffoldState();
}

class _ExtendedCupertinoPageScaffoldState extends State<ExtendedCupertinoPageScaffold> {
  void _handleStatusBarTap() {
    final ScrollController? primaryScrollController = PrimaryScrollController.maybeOf(context);
    // Only act on the scroll controller if it has any attached scroll positions.
    if (primaryScrollController != null && primaryScrollController.hasClients) {
      primaryScrollController.animateTo(
        0.0,
        // Eyeballed from iOS.
        duration: const Duration(milliseconds: 500),
        curve: Curves.linearToEaseOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget paddedContent = widget.child;

    final MediaQueryData existingMediaQuery = MediaQuery.of(context);
    if (widget.navigationBar != null) {
      // TODO(xster): Use real size after partial layout instead of preferred size.
      // https://github.com/flutter/flutter/issues/12912
      final double topPadding = widget.navigationBar!.preferredSize.height + existingMediaQuery.padding.top;

      // Propagate bottom padding and include viewInsets if appropriate
      final double bottomPadding = widget.resizeToAvoidBottomInset ? existingMediaQuery.viewInsets.bottom : 0.0;

      final EdgeInsets newViewInsets = widget.resizeToAvoidBottomInset
          // The insets are consumed by the scaffolds and no longer exposed to
          // the descendant subtree.
          ? existingMediaQuery.viewInsets.copyWith(bottom: 0.0)
          : existingMediaQuery.viewInsets;

      final bool fullObstruction = widget.navigationBar!.shouldFullyObstruct(context);

      // If navigation bar is opaquely obstructing, directly shift the main content
      // down. If translucent, let main content draw behind navigation bar but hint the
      // obstructed area.
      if (fullObstruction) {
        paddedContent = MediaQuery(
          data: existingMediaQuery
              // If the navigation bar is opaque, the top media query padding is fully consumed by the navigation bar.
              .removePadding(removeTop: true)
              .copyWith(
                viewInsets: newViewInsets,
              ),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            child: paddedContent,
          ),
        );
      } else {
        paddedContent = MediaQuery(
          data: existingMediaQuery.copyWith(
            padding: existingMediaQuery.padding.copyWith(
              top: topPadding,
            ),
            viewInsets: newViewInsets,
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: paddedContent,
          ),
        );
      }
    } else {
      // If there is no navigation bar, still may need to add padding in order
      // to support resizeToAvoidBottomInset.
      final double bottomPadding = widget.resizeToAvoidBottomInset ? existingMediaQuery.viewInsets.bottom : 0.0;
      paddedContent = Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: paddedContent,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.maybeResolve(widget.backgroundColor, context) ??
            CupertinoTheme.of(context).scaffoldBackgroundColor,
      ),
      child: Stack(
        children: <Widget>[
          // The main content being at the bottom is added to the stack first.
          paddedContent,
          if (widget.navigationBar != null)
            Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              child: MediaQuery.withNoTextScaling(
                child: widget.navigationBar!,
              ),
            ),
          // Add a touch handler the size of the status bar on top of all contents
          // to handle scroll to top by status bar taps.
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            height: existingMediaQuery.padding.top,
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: _handleStatusBarTap,
            ),
          ),
        ],
      ),
    );
  }
}
