part of 'index.dart';

/// 新、旧值回调
typedef ElUpdateCallback<T> = bool? Function(T newValue, T oldValue);

/// 小部件构建器
typedef ElWidgetBuilder = Widget Function(BuildContext context, Widget child);
