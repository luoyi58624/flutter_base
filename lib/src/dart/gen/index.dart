import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta_meta.dart';

import '../extensions/index.dart';

part 'json_util.dart';

part 'merge_util.dart';

part 'model.dart';

part 'serialize.dart';

part 'source_generator.dart';

/// 通用的 null 占位符，允许用户设置 null 来取消默认值，例如：
/// * copyWith 的参数以此为默认值，用户可以明确设置 null 表示覆写 null 值；
/// * 对象参数也可以设置此参数，表示一个默认值，用户指定 null 表示移除默认值；
const $absent = _A();

final class _A {
  const _A();
}
