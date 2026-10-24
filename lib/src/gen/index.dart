import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

import '../dart/extensions/index.dart';
import '../dart/gen/index.dart';

// 实现共享同一 library，使跨文件协作的生成器、配置与工具都能保持私有。
part 'config.dart';
part 'model_generator.dart';
part 'source_generator.dart';
part 'utils.dart';

/// 创建模型序列化、复制与合并代码的构建器。
Builder elModelBuilder(BuilderOptions options) {
  return SharedPartBuilder([
    _ModelGenerator(_ModelTemplateConfig(options.config)),
  ], 'model_generator');
}

/// 创建把标记类源码生成为字符串 getter 的 builder。
Builder elSourceGeneratorBuilder(BuilderOptions options) {
  return SharedPartBuilder([_SourceGenerator()], 'sourceGenerator');
}
