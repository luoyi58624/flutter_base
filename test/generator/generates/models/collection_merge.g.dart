// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/collection_merge.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension CollectionMergeModelExt on CollectionMergeModel {
  CollectionMergeModel copyWith({
    Object? vars = $elAbsent,
    Object? styles = $elAbsent,
    Object? counts,
    Object? plain = $elAbsent,
  }) {
    return CollectionMergeModel(
      vars: identical(vars, $elAbsent)
          ? this.vars
          : (vars == null
                ? null
                : (this.vars == null
                      ? vars as Map<String, Object>
                      : $elMergeMap(this.vars!, vars as Map<String, Object>))),
      styles: identical(styles, $elAbsent)
          ? this.styles
          : (styles == null
                ? null
                : (this.styles == null
                      ? styles as Map<String, AnimalModel>
                      : $elMergeMapDeep(
                          this.styles!,
                          styles as Map<String, AnimalModel>,
                          (a, b) => a.merge(b),
                        ))),
      counts: counts == null
          ? this.counts
          : $elMergeMap(this.counts, counts as Map<String, int>),
      plain: identical(plain, $elAbsent)
          ? this.plain
          : plain as Map<String, int>?,
    );
  }

  CollectionMergeModel merge([CollectionMergeModel? other]) {
    if (other == null) return this;
    return CollectionMergeModel(
      vars: vars == null
          ? other.vars
          : (other.vars == null ? vars : $elMergeMap(vars!, other.vars!)),
      styles: styles == null
          ? other.styles
          : (other.styles == null
                ? styles
                : $elMergeMapDeep(
                    styles!,
                    other.styles!,
                    (a, b) => a.merge(b),
                  )),
      counts: $elMergeMap(counts, other.counts),
      plain: other.plain ?? plain,
    );
  }

  List<Object?> get _props => [vars, styles, counts, plain];
}

extension SlotFieldModelExt on SlotFieldModel {
  SlotFieldModel copyWith({
    Object? width = $elAbsent,
    Object? anyValue,
    Object? dyn = $elAbsent,
  }) {
    return SlotFieldModel(
      width: identical(width, $elAbsent) ? this.width : width,
      anyValue: anyValue ?? this.anyValue,
      dyn: identical(dyn, $elAbsent) ? this.dyn : dyn,
    );
  }

  SlotFieldModel merge([SlotFieldModel? other]) {
    if (other == null) return this;
    return SlotFieldModel(
      width: other.width ?? width,
      anyValue: other.anyValue,
      dyn: other.dyn ?? dyn,
    );
  }

  List<Object?> get _props => [width, anyValue, dyn];
}
