part of 'recognizers.dart';

/// 让同一交互的多个识别器共享官方归属，获胜后仍各自维护识别生命周期。
///
/// 团队只向 Flutter 竞技场提交一个席位；任何外部赢家都会同步拒绝全部成员。
/// 适用于按压后继续拖拽或缩放，不会复活已经自行拒绝的成员。
final class ElGestureArenaTeam extends GestureArenaTeam {
  /// 创建协作团队，成员通过官方的 team 属性加入。
  ElGestureArenaTeam({this.parent}) {
    captain = _captain;
  }

  /// 与祖先团队共享官方席位，已经加入的指针仍由其原席位结算。
  ElGestureArenaTeam? parent;

  late final _CooperativeCaptain _captain = _CooperativeCaptain(this);
  final Map<int, _CooperativePointer> _pointers = {};

  @override
  GestureArenaEntry add(int pointer, GestureArenaMember member) {
    if (parent != null) {
      final visited = <ElGestureArenaTeam>{this};
      var root = parent!;
      while (root.parent != null) {
        if (!visited.add(root)) throw StateError('手势团队 parent 链不能循环。');
        root = root.parent!;
      }
      if (!visited.add(root)) throw StateError('手势团队 parent 链不能循环。');
      return root.add(pointer, member);
    }
    final state = _pointers.putIfAbsent(pointer, () {
      final state = _CooperativePointer();
      // 队长也登记为成员，外部拒绝时先于代理收到结果，避免把团队内让位误判为落败。
      state.captainEntry = super.add(pointer, _captain);
      return state;
    });
    final delegate = _CooperativeMember(state, member);
    state.members.add(delegate);
    return _CooperativeEntry(super.add(pointer, delegate), delegate, pointer);
  }
}

final class _CooperativePointer {
  late final GestureArenaEntry captainEntry;
  final List<_CooperativeMember> members = [];
  GestureDisposition? result;
}

final class _CooperativeCaptain extends GestureArenaMember {
  _CooperativeCaptain(this.team);
  final ElGestureArenaTeam team;

  void _finish(int pointer, GestureDisposition result) {
    final state = team._pointers.remove(pointer);
    if (state == null) return;
    state.result = result;
    for (final member in state.members.toList()) {
      member.finish(pointer, result);
    }
  }

  @override
  void acceptGesture(int pointer) =>
      _finish(pointer, GestureDisposition.accepted);

  @override
  void rejectGesture(int pointer) =>
      _finish(pointer, GestureDisposition.rejected);
}

final class _CooperativeMember extends GestureArenaMember {
  _CooperativeMember(this.state, this.member);
  final _CooperativePointer state;
  final GestureArenaMember member;
  bool withdrawn = false;
  bool notified = false;

  void finish(int pointer, GestureDisposition disposition) {
    if (notified) return;
    notified = true;
    if (!withdrawn && disposition == GestureDisposition.accepted) {
      member.acceptGesture(pointer);
    } else {
      member.rejectGesture(pointer);
    }
  }

  @override
  void acceptGesture(int pointer) =>
      finish(pointer, GestureDisposition.accepted);

  @override
  void rejectGesture(int pointer) {
    // 官方团队先拒绝队长以外的成员，再通知队长获胜；等队长给出团队最终结果。
    if (withdrawn || state.result != null) {
      finish(pointer, state.result ?? GestureDisposition.rejected);
    }
  }
}

final class _CooperativeEntry implements GestureArenaEntry {
  _CooperativeEntry(this.entry, this.delegate, this.pointer);
  final GestureArenaEntry entry;
  final _CooperativeMember delegate;
  final int pointer;
  bool resolved = false;

  @override
  void resolve(GestureDisposition disposition) {
    if (resolved || delegate.state.result != null) return;
    resolved = true;
    if (disposition == GestureDisposition.rejected) delegate.withdrawn = true;
    entry.resolve(disposition);
    final state = delegate.state;
    if (state.result == null &&
        state.members.every((member) => member.withdrawn)) {
      state.captainEntry.resolve(GestureDisposition.rejected);
    }
  }
}
