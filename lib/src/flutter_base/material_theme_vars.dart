part of 'material_theme.dart';

({Map<Object, Object> vars, InheritedText? text}) _materialStyle(BuildContext context, Brightness brightness) {
  final defaults = {...ElTheme.lightVars, if (brightness == Brightness.dark) ...ElTheme.darkVars};
  final host = StyleDependencyScope.maybeHostOf(context);
  if (host == null) return (vars: defaults, text: null);
  final source = _materialSources[host] ??= _MaterialSource(host);
  source.depend(context as Element);
  if (host.internalStateHas(ViewState.dark) == (brightness == Brightness.dark)) {
    return (vars: {...defaults, ...host.internalVars}, text: host.committedResolvedStyle.inheritedText);
  }
  // 未激活的 onDark 不能从已提交值倒推，按相同变体顺序重放原声明。
  final dark = 1 << ViewState.dark.index;
  ResolvedStyle? resolved;
  for (final node in source.nodes.reversed) {
    final state = (node.internalStateBits & ~dark) | (brightness == Brightness.dark ? dark : 0);
    resolved = StyleResolver.resolve(style: node.style, parent: resolved, state: state);
  }
  return (vars: {...defaults, ...?resolved?.inheritedVars.map}, text: resolved?.inheritedText);
}

final _materialSources = Expando<_MaterialSource>();

// 复用已有级联通知和 Element 退订关系，不创建另一套主题继承小部件。
class _MaterialSource implements BuildDependencySource {
  _MaterialSource(this.host);
  final ElRenderView host;
  final _dependents = <Element>{};
  final _listeners = <ElRenderView, Listenable>{};
  List<ElRenderView> nodes = [];
  bool _scheduled = false;

  void depend(Element element) {
    final next = <ElRenderView>[];
    for (ElRenderView? node = host; node != null; node = node.internalStyleParent) {
      next.add(node);
    }
    for (final node in nodes) {
      if (!next.contains(node)) _listeners.remove(node)?.removeListener(_changed);
    }
    for (final node in next) {
      if (!nodes.contains(node)) {
        final changes = node.ensureCascadeBridgeChanges();
        _listeners[node] = changes;
        changes.addListener(_changed);
      }
    }
    nodes = next;
    _dependents.add(element);
    StyleDependencyScope.dependOnBuildSource(element, this);
  }

  void _changed() {
    if (_scheduled || _dependents.isEmpty) return;
    _scheduled = true;
    // 样式提交可能发生在布局中，帧末合并后再通知官方 Theme 消费者。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      for (final element in _dependents.toList()) {
        if (element.mounted) element.markNeedsBuild();
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void removeBuildDependent(Element dependent) {
    _dependents.remove(dependent);
    if (_dependents.isNotEmpty) return;
    for (final changes in _listeners.values) {
      changes.removeListener(_changed);
    }
    _listeners.clear();
    nodes = [];
  }
}
