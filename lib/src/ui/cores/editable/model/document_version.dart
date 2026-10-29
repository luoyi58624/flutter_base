import 'package:flutter/foundation.dart' show immutable, internal;

/// 把模型身份与文档修订绑定为不可伪造业务含义的版本令牌。
///
/// 令牌只提供相等判断、哈希与诊断文本；调用方不能读取或推算其中的模型身份与
/// 修订号。由同一控制器在同一修订上取得的令牌相等，不同控制器即使修订号相同
/// 也不相等。
@immutable
final class DocumentVersion {
  const DocumentVersion._(this._modelIdentity, this._revision);

  final Object _modelIdentity;
  final int _revision;

  /// 仅当模型身份与修订均相同时才判定相等。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentVersion && identical(_modelIdentity, other._modelIdentity) && _revision == other._revision;

  /// 返回与令牌相等语义一致的哈希值。
  @override
  int get hashCode => Object.hash(identityHashCode(_modelIdentity), _revision);

  /// 返回仅供日志诊断使用的模型标签与修订号。
  @override
  String toString() =>
      'DocumentVersion(model: #${identityHashCode(_modelIdentity).toRadixString(16)}, revision: $_revision)';
}

/// 控制器内部签发并校验 [DocumentVersion]，不属于公开导出面。
@internal
final class DocumentVersionIssuer {
  final Object _modelIdentity = Object();

  /// 签发绑定当前模型与 [revision] 的版本令牌。
  DocumentVersion issue(int revision) {
    assert(revision >= 0);
    return DocumentVersion._(_modelIdentity, revision);
  }

  /// 判断 [version] 是否绑定当前模型的指定 [revision]。
  bool matches(DocumentVersion version, int revision) =>
      identical(version._modelIdentity, _modelIdentity) && version._revision == revision;

  /// 读取当前模型令牌的内部修订号，跨模型令牌会立即失败。
  int revisionOf(DocumentVersion version) {
    if (!identical(version._modelIdentity, _modelIdentity)) {
      throw StateError('文档版本不属于当前 EditableController：$version。');
    }
    return version._revision;
  }
}
