import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'model_generator.dart';
import 'source_generator.dart';
import 'config.dart';

/// 创建模型序列化、复制与合并代码的构建器。
Builder elModelBuilder(BuilderOptions options) {
  return SharedPartBuilder([
    ElModelGenerator(ModelTemplateConfig(options.config)),
  ], 'model_generator');
}

/// 创建把标记类源码生成为字符串 getter 的 builder。
Builder elSourceGeneratorBuilder(BuilderOptions options) {
  return SharedPartBuilder([ElSourceTextGenerator()], 'sourceGenerator');
}
