import 'package:equatable/equatable.dart';
import 'package:flutter_base/dart.dart';

import 'animal.dart';

part '../generates/models/collection_merge.g.dart';

// ========================================================================
// 测试 Map 字段的集合合并生成:
// - vars    → useMerge + value 无 merge 能力 → 逐 key 并集
// - styles  → useMerge + value(AnimalModel)可 merge → key 并集 + 同 key 深合并
// - counts  → 非空 Map + useMerge → 并集(非空侧无三元包裹)
// - plain   → 未标 useMerge → 整体替换(对照组)
// ========================================================================

@ElModelGenerator.copy(generateProps: true)
class CollectionMergeModel with Equatable {
  @ElFieldGenerator(useMerge: true)
  final Map<String, Object>? vars;

  @ElFieldGenerator(useMerge: true)
  final Map<String, AnimalModel>? styles;

  @ElFieldGenerator(useMerge: true)
  final Map<String, int> counts;

  final Map<String, int>? plain;

  const CollectionMergeModel({
    this.vars,
    this.styles,
    this.counts = const {},
    this.plain,
  });

  @override
  List<Object?> get props => _props;
}

// ========================================================================
// Object? / Object 槽位字段(ElStyle 形态预演):cast 应省略
// ========================================================================

@ElModelGenerator.copy(generateProps: true)
class SlotFieldModel with Equatable {
  final Object? width;
  final Object anyValue;
  final dynamic dyn;

  const SlotFieldModel({this.width, this.anyValue = 0, this.dyn});

  @override
  List<Object?> get props => _props;
}
