import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// 单个模型生成器实例的不可变配置。
class ModelTemplateConfig {
  /// 声明扩展后缀，默认 Ext
  final String extSuffix;

  const ModelTemplateConfig._({required this.extSuffix});

  /// 从构建选项读取并校验扩展名称后缀。
  factory ModelTemplateConfig(Map<String, dynamic> config) {
    final suffix = config['ext_suffix'] ?? 'Ext';
    if (suffix is! String || suffix.isEmpty) {
      throw ArgumentError.value(suffix, 'ext_suffix', '必须是非空字符串。');
    }
    final name = 'Model$suffix';
    final parsed = parseString(
      content: 'extension $name on Object {}',
      throwIfDiagnostics: false,
    );
    final declarations = parsed.unit.declarations;
    if (parsed.errors.isNotEmpty ||
        declarations.length != 1 ||
        declarations.single is! ExtensionDeclaration ||
        (declarations.single as ExtensionDeclaration).name?.lexeme != name) {
      throw ArgumentError.value(suffix, 'ext_suffix', '不能构成合法的扩展名称。');
    }
    return ModelTemplateConfig._(extSuffix: suffix);
  }
}
