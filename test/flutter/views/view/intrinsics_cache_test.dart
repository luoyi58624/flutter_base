import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _IntrinsicView extends ElRenderView {
  final calls = List<int>.filled(4, 0);

  @override
  double computeMinIntrinsicWidth(double height) {
    calls[0]++;
    return super.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    calls[1]++;
    return super.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    calls[2]++;
    return super.computeMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    calls[3]++;
    return super.computeMaxIntrinsicHeight(width);
  }
}

class _IntrinsicContent extends RenderBox {
  final calls = List<int>.filled(4, 0);
  double extent = 10;

  @override
  double computeMinIntrinsicWidth(double height) {
    calls[0]++;
    return extent;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    calls[1]++;
    return extent * 2;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    calls[2]++;
    return extent + width;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    calls[3]++;
    return extent * 2 + width;
  }
}

void main() {
  test('四种查询复用框架缓存，交错输入也各自保留结果', () {
    final view = _IntrinsicView();
    final child = _IntrinsicContent();
    view.add(child);
    addTearDown(() {
      view.remove(child);
      child.dispose();
      view.dispose();
    });
    final queries = [
      view.getMinIntrinsicWidth,
      view.getMaxIntrinsicWidth,
      view.getMinIntrinsicHeight,
      view.getMaxIntrinsicHeight,
    ];
    for (final (index, query) in queries.indexed) {
      final first = query(30);
      query(60);
      expect(query(30), first);
      expect(view.calls[index], 2);
    }
    expect(child.calls, [1, 1, 2, 2]);
    expect(view.hasSize, isFalse);
    expect(child.hasSize, isFalse);
  });

  test('子节点标脏同时清理框架缓存并通知宿主', () {
    final view = _IntrinsicView();
    final child = _IntrinsicContent();
    view.add(child);
    addTearDown(() {
      view.remove(child);
      child.dispose();
      view.dispose();
    });
    expect(view.getMinIntrinsicWidth(30), 10);
    expect(view.getMaxIntrinsicWidth(30), 20);
    expect(view.getMinIntrinsicHeight(30), 40);
    expect(view.getMaxIntrinsicHeight(30), 50);
    child.extent = 25;
    child.markNeedsLayout();
    expect(view.getMinIntrinsicWidth(30), 25);
    expect(view.getMaxIntrinsicWidth(30), 50);
    expect(view.getMinIntrinsicHeight(30), 55);
    expect(view.getMaxIntrinsicHeight(30), 80);
    expect(view.calls, [2, 2, 2, 2]);
    expect(child.calls, [2, 2, 2, 2]);
    expect(view.hasSize, isFalse);
    expect(child.hasSize, isFalse);
  });
}
