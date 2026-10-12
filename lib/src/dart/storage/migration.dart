/// 存储业务数据迁移函数，直接修改传入的快照数据即可。
typedef ElStorageMigrate = void Function(Map<String, dynamic> data);

/// 描述一次存储业务数据版本迁移。
class ElStorageMigration {
  /// 创建从 [from] 版本迁移到 [to] 版本的规则。
  const ElStorageMigration({required this.from, required this.to, required this.migrate});

  /// 迁移前的数据版本。
  final int from;

  /// 迁移后的数据版本。
  final int to;

  /// 执行迁移，直接修改传入的 Map。
  final ElStorageMigrate migrate;
}

/// 存储迁移失败。
class ElStorageMigrationException implements Exception {
  /// 创建迁移异常。
  const ElStorageMigrationException(this.message, [this.error]);

  /// 错误说明。
  final String message;

  /// 原始异常。
  final Object? error;

  @override
  String toString() =>
      error == null ? 'ElStorageMigrationException: $message' : 'ElStorageMigrationException: $message\n$error';
}
