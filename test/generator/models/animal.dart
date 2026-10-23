import 'package:equatable/equatable.dart';
import 'package:flutter_base/dart.dart';

part '../generates/models/animal.g.dart';

@ElModelGenerator.all()
class AnimalModel with Equatable implements ElSerializeModel {
  final String? name;
  final String? type;

  const AnimalModel({this.name, this.type});

  AnimalModel.name({this.name, this.type});

  @override
  AnimalModel fromJson(Map<String, dynamic>? json) =>
      AnimalModelExt.fromJson(json);

  @override
  Map<String, dynamic> toJson() => _toJson();

  @override
  List<Object?> get props => _props;
}
