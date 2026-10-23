// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/animal.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension AnimalModelExt on AnimalModel {
  static const AnimalModel defaultModel = AnimalModel();

  static AnimalModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return AnimalModel(
      name: $ElJsonUtil.$string(json, "name", "name"),
      type: $ElJsonUtil.$string(json, "type", "type"),
    );
  }

  Map<String, dynamic> _toJson() {
    return {"name": name, "type": type};
  }

  AnimalModel copyWith({Object? name = $elAbsent, Object? type = $elAbsent}) {
    return AnimalModel(
      name: identical(name, $elAbsent) ? this.name : name as String?,
      type: identical(type, $elAbsent) ? this.type : type as String?,
    );
  }

  AnimalModel merge([AnimalModel? other]) {
    if (other == null) return this;
    return AnimalModel(name: other.name ?? name, type: other.type ?? type);
  }

  List<Object?> get _props => [name, type];
}
