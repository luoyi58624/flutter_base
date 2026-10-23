part of 'index.dart';

/// 将被标记类的源码生成为指定名称的字符串 getter。
@Target({TargetKind.classType})
class ElSourceGenerator {
  /// 创建源码字符串生成标记，[name] 是生成的顶层 getter 名称。
  const ElSourceGenerator(this.name);

  /// 生成的顶层字符串 getter 名称。
  final String name;
}
