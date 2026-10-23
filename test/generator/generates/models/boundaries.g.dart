// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/boundaries.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension BoundaryModelExt on BoundaryModel {
  static const BoundaryModel defaultModel = BoundaryModel(
    value: "It's \\ready\n\$value",
    labels: ["It's \\ready\n\$value"],
    mapping: {"user's\\key\$id\n下一行": "It's \\ready\n\$value"},
    statuses: [],
  );

  static BoundaryModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return BoundaryModel(
      value:
          $ElJsonUtil.$string(
            json,
            "user's\\key\$id\n下一行",
            "user's\\key\$id\n下一行",
          ) ??
          "It's \\ready\n\$value",
      labels:
          $ElJsonUtil.$list<String>(json, "labels", null, "labels") ??
          ["It's \\ready\n\$value"],
      mapping:
          $ElJsonUtil.$map<String>(json, "mapping", null, "mapping") ??
          {"user's\\key\$id\n下一行": "It's \\ready\n\$value"},
      status:
          $ElJsonUtil.$custom<BoundaryStatus>(
            json,
            "status",
            (const ElEnumSerialize(BoundaryStatus.values)),
            "status",
          ) ??
          BoundaryStatus.ready,
      duration:
          $ElJsonUtil.$custom<Duration>(
            json,
            "duration",
            (const serializers.DurationUnits.units(scale: 10)),
            "duration",
          ) ??
          Duration.zero,
      statuses:
          $ElJsonUtil.$listCustom<BoundaryStatus?>(
            json,
            "statuses",
            (const ElEnumSerialize(BoundaryStatus.values)),
            "statuses",
          ) ??
          [],
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      "user's\\key\$id\n下一行": value,
      "labels": labels,
      "mapping": mapping,
      "status": (const ElEnumSerialize(BoundaryStatus.values))
          .serialize(status),
      "duration": (const serializers.DurationUnits.units(scale: 10))
          .serialize(duration),
      "statuses": statuses
          .map(
            (e) => (const ElEnumSerialize(BoundaryStatus.values)).serialize(e),
          )
          .toList(),
    };
  }

  BoundaryModel copyWith({
    Object? value,
    Object? labels,
    Object? mapping,
    Object? status,
    Object? duration,
    Object? statuses,
  }) {
    return BoundaryModel(
      value: value == null ? this.value : value as String,
      labels: labels == null ? this.labels : labels as List<String>,
      mapping: mapping == null ? this.mapping : mapping as Map<String, String>,
      status: status == null ? this.status : status as BoundaryStatus,
      duration: duration == null ? this.duration : duration as Duration,
      statuses: statuses == null
          ? this.statuses
          : statuses as List<BoundaryStatus?>,
    );
  }

  BoundaryModel merge([BoundaryModel? other]) {
    if (other == null) return this;
    return BoundaryModel(
      value: other.value,
      labels: other.labels,
      mapping: other.mapping,
      status: other.status,
      duration: other.duration,
      statuses: other.statuses,
    );
  }
}

extension BoundaryLeafExt on BoundaryLeaf {
  static const BoundaryLeaf defaultModel = BoundaryLeaf(name: '');

  static BoundaryLeaf fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return BoundaryLeaf(name: $ElJsonUtil.$string(json, "name", "name") ?? '');
  }

  Map<String, dynamic> _toJson() {
    return {"name": name};
  }

  BoundaryLeaf copyWith({Object? name}) {
    return BoundaryLeaf(name: name == null ? this.name : name as String);
  }

  BoundaryLeaf merge([BoundaryLeaf? other]) {
    if (other == null) return this;
    return BoundaryLeaf(name: other.name);
  }
}

extension NestedBoundaryModelExt on NestedBoundaryModel {
  static const NestedBoundaryModel defaultModel = NestedBoundaryModel(
    matrix: {},
    rows: [],
    leaves: {},
    sets: {},
    times: {},
    strictTimes: [],
  );

  static NestedBoundaryModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return NestedBoundaryModel(
      matrix:
          $ElJsonUtil.$decode<Map<String, Map<String, int>>>(
            json,
            "matrix",
            (value) => value is Map
                ? value.map<String, Map<String, int>>(
                    (key, item) => MapEntry(
                      key as String,
                      (item as Map).map<String, int>(
                        (key, item) => MapEntry(key as String, item as int),
                      ),
                    ),
                  )
                : null,
            "matrix",
          ) ??
          {},
      rows:
          $ElJsonUtil.$decode<List<Map<String, List<int?>>>>(
            json,
            "rows",
            (value) => value is List
                ? value
                      .map<Map<String, List<int?>>>(
                        (item) => (item as Map).map<String, List<int?>>(
                          (key, item) => MapEntry(
                            key as String,
                            (item as List)
                                .map<int?>(
                                  (item) => (item == null ? null : item as int),
                                )
                                .toList(),
                          ),
                        ),
                      )
                      .toList()
                : null,
            "rows",
          ) ??
          [],
      leaves:
          $ElJsonUtil.$decode<Map<String, List<BoundaryLeaf?>>>(
            json,
            "leaves",
            (value) => value is Map
                ? value.map<String, List<BoundaryLeaf?>>(
                    (key, item) => MapEntry(
                      key as String,
                      (item as List)
                          .map<BoundaryLeaf?>(
                            (item) => (item == null
                                ? null
                                : BoundaryLeafExt.defaultModel.fromJson(
                                    item is Map
                                        ? Map<String, dynamic>.from(item)
                                        : null,
                                  )),
                          )
                          .toList(),
                    ),
                  )
                : null,
            "leaves",
          ) ??
          {},
      sets:
          $ElJsonUtil.$decode<Map<String, Set<int>>>(
            json,
            "sets",
            (value) => value is Map
                ? value.map<String, Set<int>>(
                    (key, item) => MapEntry(
                      key as String,
                      (item as Iterable)
                          .map<int>((item) => item as int)
                          .toSet(),
                    ),
                  )
                : null,
            "sets",
          ) ??
          {},
      optionalRows: $ElJsonUtil.$decode<List<List<int>?>?>(
        json,
        "optionalRows",
        (value) => value is List
            ? value
                  .map<List<int>?>(
                    (item) => (item == null
                        ? null
                        : (item as List)
                              .map<int>((item) => item as int)
                              .toList()),
                  )
                  .toList()
            : null,
        "optional_rows",
      ),
      times:
          $ElJsonUtil.$decode<Map<String, List<Duration?>>>(
            json,
            "times",
            (value) => value is Map
                ? value.map<String, List<Duration?>>(
                    (key, item) => MapEntry(
                      key as String,
                      (item as List)
                          .map(
                            (item) => $ElJsonUtil.$customValue(
                              (const serializers.DurationUnits.units(
                                scale: 10,
                              )),
                              item,
                            ),
                          )
                          .whereType<Duration?>()
                          .toList(),
                    ),
                  )
                : null,
            "times",
          ) ??
          {},
      strictTimes:
          $ElJsonUtil.$decode<List<Map<String, Duration>>>(
            json,
            "strictTimes",
            (value) => value is List
                ? value
                      .map<Map<String, Duration>>(
                        (item) => (() {
                          final result = <String, Duration>{};
                          for (final entry in (item as Map).entries) {
                            final decoded = $ElJsonUtil.$customValue(
                              (const serializers.DurationUnits.units(
                                scale: 10,
                              )),
                              entry.value,
                            );
                            if (decoded is Duration) {
                              result[entry.key as String] = decoded;
                            }
                          }
                          return result;
                        })(),
                      )
                      .toList()
                : null,
            "strict_times",
          ) ??
          [],
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      "matrix": matrix.map(
        (key, item) =>
            MapEntry(key, item.map((key, item) => MapEntry(key, item))),
      ),
      "rows": rows
          .map(
            (item) => item.map(
              (key, item) => MapEntry(key, item.map((item) => item).toList()),
            ),
          )
          .toList(),
      "leaves": leaves.map(
        (key, item) =>
            MapEntry(key, item.map((item) => item?.toJson()).toList()),
      ),
      "sets": sets.map(
        (key, item) => MapEntry(key, item.map((item) => item).toList()),
      ),
      "optionalRows": optionalRows
          ?.map((item) => item?.map((item) => item).toList())
          .toList(),
      "times": times.map(
        (key, item) => MapEntry(
          key,
          item
              .map(
                (item) =>
                    (const serializers.DurationUnits.units(scale: 10))
                        .serialize(item),
              )
              .toList(),
        ),
      ),
      "strictTimes": strictTimes
          .map(
            (item) => item.map(
              (key, item) => MapEntry(
                key,
                (const serializers.DurationUnits.units(scale: 10))
                    .serialize(item),
              ),
            ),
          )
          .toList(),
    };
  }

  NestedBoundaryModel copyWith({
    Object? matrix,
    Object? rows,
    Object? leaves,
    Object? sets,
    Object? optionalRows = $elAbsent,
    Object? times,
    Object? strictTimes,
  }) {
    return NestedBoundaryModel(
      matrix: matrix == null
          ? this.matrix
          : matrix as Map<String, Map<String, int>>,
      rows: rows == null ? this.rows : rows as List<Map<String, List<int?>>>,
      leaves: leaves == null
          ? this.leaves
          : leaves as Map<String, List<BoundaryLeaf?>>,
      sets: sets == null ? this.sets : sets as Map<String, Set<int>>,
      optionalRows: identical(optionalRows, $elAbsent)
          ? this.optionalRows
          : optionalRows as List<List<int>?>?,
      times: times == null ? this.times : times as Map<String, List<Duration?>>,
      strictTimes: strictTimes == null
          ? this.strictTimes
          : strictTimes as List<Map<String, Duration>>,
    );
  }

  NestedBoundaryModel merge([NestedBoundaryModel? other]) {
    if (other == null) return this;
    return NestedBoundaryModel(
      matrix: other.matrix,
      rows: other.rows,
      leaves: other.leaves,
      sets: other.sets,
      optionalRows: other.optionalRows ?? optionalRows,
      times: other.times,
      strictTimes: other.strictTimes,
    );
  }
}
