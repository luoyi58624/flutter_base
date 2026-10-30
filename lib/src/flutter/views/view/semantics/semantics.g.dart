// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'semantics.dart';

// **************************************************************************
// ElModelCodeGenerator
// **************************************************************************

extension ElSemanticsExt on ElSemantics {
  ElSemantics copyWith({
    Object? container,
    Object? explicitChildNodes,
    Object? exclude,
    Object? mergeDescendants,
    Object? blockUserActions,
    Object? blockPreviousSemantics,
    Object? indexInParent = $absent,
    Object? localeForSubtree = $absent,
  }) {
    return ElSemantics(
      container: container == null ? this.container : container as bool,
      explicitChildNodes: explicitChildNodes == null ? this.explicitChildNodes : explicitChildNodes as bool,
      exclude: exclude == null ? this.exclude : exclude as bool,
      mergeDescendants: mergeDescendants == null ? this.mergeDescendants : mergeDescendants as bool,
      blockUserActions: blockUserActions == null ? this.blockUserActions : blockUserActions as bool,
      blockPreviousSemantics: blockPreviousSemantics == null
          ? this.blockPreviousSemantics
          : blockPreviousSemantics as bool,
      indexInParent: identical(indexInParent, $absent) ? this.indexInParent : indexInParent as int?,
      localeForSubtree: identical(localeForSubtree, $absent) ? this.localeForSubtree : localeForSubtree as Locale?,
    );
  }

  ElSemantics merge([ElSemantics? other]) {
    if (other == null) return this;
    return ElSemantics(
      container: other.container,
      explicitChildNodes: other.explicitChildNodes,
      exclude: other.exclude,
      mergeDescendants: other.mergeDescendants,
      blockUserActions: other.blockUserActions,
      blockPreviousSemantics: other.blockPreviousSemantics,
      indexInParent: other.indexInParent ?? indexInParent,
      localeForSubtree: other.localeForSubtree ?? localeForSubtree,
    );
  }
}
