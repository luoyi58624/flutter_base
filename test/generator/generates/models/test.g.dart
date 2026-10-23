// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../models/test.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

extension TestModelExt on TestModel {
  static final TestModel defaultModel = TestModel(
    stringField: '',
    stringField3: 'hello',
    stringField4: 'hello',
    numField: 0.0,
    numField3: 10.0,
    numField4: 10,
    intField: 0,
    intField3: 10,
    intField4: 20,
    doubleField: 0.0,
    doubleField3: 10.0,
    doubleField4: 10.0,
    boolField: false,
    boolField3: true,
    boolField4: true,
    listField: [
      1,
      'hello',
      false,
      ['hihi'],
    ],
    listField2: [1, 'hello', false],
    listStringField: [],
    listStringField3: ['hello', 'world'],
    listIntField: [],
    listIntField3: [1, 2, 3, 4, 5],
    listDoubleField: [],
    listDoubleField3: [1, 2, 3, 4, 5],
    setField: {'hihi'},
    mapField: {},
    mapField2: {
      'name': 'hihi',
      'child': {'age': 20},
    },
    userModel: UserModelExt.defaultModel,
    userModel2: const UserModel(
      username: 'hihi',
      age: 30,
      count: null,
      child: UserModel(
        username: 'xx',
        age: 14,
        count: null,
        child: null,
        children: null,
        animalMap: null,
        mapField: null,
        startDate: null,
        endDate: null,
      ),
      children: [
        UserModel(
          username: 'one',
          age: 18,
          count: null,
          child: null,
          children: null,
          animalMap: null,
          mapField: null,
          startDate: null,
          endDate: null,
        ),
        UserModel(
          username: 'two',
          age: 4,
          count: null,
          child: null,
          children: null,
          animalMap: null,
          mapField: null,
          startDate: null,
          endDate: null,
        ),
      ],
      animalMap: {
        'one': AnimalModel(name: '旺财', type: '小狗'),
        'two': AnimalModel(name: '小白', type: '猫咪'),
      },
      mapField: null,
      startDate: null,
      endDate: null,
    ),
    myAnimal: AnimalModelExt.defaultModel,
    myDog: const AnimalModel(name: '旺财', type: '小狗'),
    animalList: [
      const AnimalModel(name: '旺财', type: '小狗'),
      const AnimalModel(name: '小白', type: '猫咪'),
    ],
  );

  static TestModel fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultModel;
    return TestModel(
      stringField:
          $ElJsonUtil.$string(json, 'custom_string', 'custom_string') ?? '',
      stringField2: $ElJsonUtil.$string(json, 'stringField2', 'string_field2'),
      stringField3:
          $ElJsonUtil.$string(json, 'stringField3', 'string_field3') ?? 'hello',
      stringField4:
          $ElJsonUtil.$string(json, 'stringField4', 'string_field4') ?? 'hello',
      numField: $ElJsonUtil.$num(json, 'numField', 'num_field') ?? 0.0,
      numField2: $ElJsonUtil.$num(json, 'numField2', 'num_field2'),
      numField3: $ElJsonUtil.$num(json, 'numField3', 'num_field3') ?? 10.0,
      numField4: $ElJsonUtil.$num(json, 'numField4', 'num_field4') ?? 10,
      intField: $ElJsonUtil.$int(json, 'intField', 'int_field') ?? 0,
      intField2: $ElJsonUtil.$int(json, 'intField2', 'int_field2'),
      intField3: $ElJsonUtil.$int(json, 'intField3', 'int_field3') ?? 10,
      intField4: $ElJsonUtil.$int(json, 'intField4', 'int_field4') ?? 20,
      doubleField:
          $ElJsonUtil.$double(json, 'doubleField', 'double_field') ?? 0.0,
      doubleField2: $ElJsonUtil.$double(json, 'doubleField2', 'double_field2'),
      doubleField3:
          $ElJsonUtil.$double(json, 'doubleField3', 'double_field3') ?? 10.0,
      doubleField4:
          $ElJsonUtil.$double(json, 'doubleField4', 'double_field4') ?? 10.0,
      boolField: $ElJsonUtil.$bool(json, 'boolField', 'bool_field') ?? false,
      boolField2: $ElJsonUtil.$bool(json, 'boolField2', 'bool_field2'),
      boolField3: $ElJsonUtil.$bool(json, 'boolField3', 'bool_field3') ?? true,
      boolField4: $ElJsonUtil.$bool(json, 'custom_bool', 'custom_bool') ?? true,
      listField:
          $ElJsonUtil.$list<dynamic>(json, 'listField', null, 'list_field') ??
          [
            1,
            'hello',
            false,
            ['hihi'],
          ],
      listField2:
          $ElJsonUtil.$list<dynamic>(json, 'listField2', null, 'list_field2') ??
          [1, 'hello', false],
      listStringField:
          $ElJsonUtil.$list<String>(
            json,
            'listStringField',
            null,
            'list_string_field',
          ) ??
          [],
      listStringField2: $ElJsonUtil.$list<String>(
        json,
        'listStringField2',
        null,
        'list_string_field2',
      ),
      listStringField3:
          $ElJsonUtil.$list<String>(
            json,
            'listStringField3',
            null,
            'list_string_field3',
          ) ??
          ['hello', 'world'],
      listStringField4: $ElJsonUtil.$list<String>(
        json,
        'listStringField4',
        null,
        'list_string_field4',
      ),
      listIntField:
          $ElJsonUtil.$list<int>(
            json,
            'listIntField',
            null,
            'list_int_field',
          ) ??
          [],
      listIntField2: $ElJsonUtil.$list<int>(
        json,
        'listIntField2',
        null,
        'list_int_field2',
      ),
      listIntField3:
          $ElJsonUtil.$list<int>(
            json,
            'listIntField3',
            null,
            'list_int_field3',
          ) ??
          [1, 2, 3, 4, 5],
      listIntField4: $ElJsonUtil.$list<int>(
        json,
        'listIntField4',
        null,
        'list_int_field4',
      ),
      listDoubleField:
          $ElJsonUtil.$list<double>(
            json,
            'listDoubleField',
            null,
            'list_double_field',
          ) ??
          [],
      listDoubleField2: $ElJsonUtil.$list<double>(
        json,
        'listDoubleField2',
        null,
        'list_double_field2',
      ),
      listDoubleField3:
          $ElJsonUtil.$list<double>(
            json,
            'listDoubleField3',
            null,
            'list_double_field3',
          ) ??
          [1, 2, 3, 4, 5],
      listDoubleField4: $ElJsonUtil.$list<double>(
        json,
        'listDoubleField4',
        null,
        'list_double_field4',
      ),
      setField:
          $ElJsonUtil.$set<dynamic>(json, 'setField', null, 'set_field') ??
          {'hihi'},
      setField2: $ElJsonUtil.$set<dynamic>(
        json,
        'setField2',
        null,
        'set_field2',
      ),
      mapField:
          $ElJsonUtil.$map<dynamic>(json, 'mapField', null, 'map_field') ?? {},
      mapField2:
          $ElJsonUtil.$map<dynamic>(json, 'mapField2', null, 'map_field2') ??
          {
            'name': 'hihi',
            'child': {'age': 20},
          },
      userModel:
          $ElJsonUtil.$model<UserModel>(
            json,
            'userModel',
            UserModelExt.defaultModel,
            'user_model',
          ) ??
          UserModelExt.defaultModel,
      userModel2:
          $ElJsonUtil.$model<UserModel?>(
            json,
            'userModel2',
            UserModelExt.defaultModel,
            'user_model2',
          ) ??
          const UserModel(
            username: 'hihi',
            age: 30,
            count: null,
            child: UserModel(
              username: 'xx',
              age: 14,
              count: null,
              child: null,
              children: null,
              animalMap: null,
              mapField: null,
              startDate: null,
              endDate: null,
            ),
            children: [
              UserModel(
                username: 'one',
                age: 18,
                count: null,
                child: null,
                children: null,
                animalMap: null,
                mapField: null,
                startDate: null,
                endDate: null,
              ),
              UserModel(
                username: 'two',
                age: 4,
                count: null,
                child: null,
                children: null,
                animalMap: null,
                mapField: null,
                startDate: null,
                endDate: null,
              ),
            ],
            animalMap: {
              'one': AnimalModel(name: '旺财', type: '小狗'),
              'two': AnimalModel(name: '小白', type: '猫咪'),
            },
            mapField: null,
            startDate: null,
            endDate: null,
          ),
      myAnimal:
          $ElJsonUtil.$model<AnimalModel>(
            json,
            'my_animal_model',
            AnimalModelExt.defaultModel,
            'my_animal_model',
          ) ??
          AnimalModelExt.defaultModel,
      myDog:
          $ElJsonUtil.$model<AnimalModel?>(
            json,
            'myDog',
            AnimalModelExt.defaultModel,
            'my_dog',
          ) ??
          const AnimalModel(name: '旺财', type: '小狗'),
      animalList:
          $ElJsonUtil.$list<AnimalModel>(
            json,
            'animalList',
            AnimalModelExt.defaultModel,
            'animal_list',
          ) ??
          [
            const AnimalModel(name: '旺财', type: '小狗'),
            const AnimalModel(name: '小白', type: '猫咪'),
          ],
      startDate: $ElJsonUtil.$custom<DateTime?>(
        json,
        'startDate',
        const ElDateTimeSerialize(),
        'start_date',
      ),
    );
  }

  Map<String, dynamic> _toJson() {
    return {
      'custom_string': stringField,
      'string_field2': stringField2,
      'string_field3': stringField3,
      'string_field4': stringField4,
      'num_field': numField,
      'num_field2': numField2,
      'num_field3': numField3,
      'num_field4': numField4,
      'int_field': intField,
      'int_field2': intField2,
      'int_field3': intField3,
      'int_field4': intField4,
      'double_field': doubleField,
      'double_field2': doubleField2,
      'double_field3': doubleField3,
      'double_field4': doubleField4,
      'bool_field': boolField,
      'bool_field2': boolField2,
      'bool_field3': boolField3,
      'custom_bool': boolField4,
      'list_field': listField,
      'list_field2': listField2,
      'list_string_field': listStringField,
      'list_string_field2': listStringField2,
      'list_string_field3': listStringField3,
      'list_string_field4': listStringField4,
      'list_int_field': listIntField,
      'list_int_field2': listIntField2,
      'list_int_field3': listIntField3,
      'list_int_field4': listIntField4,
      'list_double_field': listDoubleField,
      'list_double_field2': listDoubleField2,
      'list_double_field3': listDoubleField3,
      'list_double_field4': listDoubleField4,
      'set_field': setField.toList(),
      'set_field2': setField2?.toList(),
      'map_field': mapField,
      'map_field2': mapField2,
      'user_model': userModel.toJson(),
      'user_model2': userModel2?.toJson(),
      'my_animal_model': myAnimal.toJson(),
      'my_dog': myDog?.toJson(),
      'animal_list': animalList.map((e) => e.toJson()).toList(),
      'start_date': const ElDateTimeSerialize().serialize(startDate),
    };
  }

  TestModel copyWith({
    Object? stringField,
    Object? stringField2 = $elAbsent,
    Object? stringField3,
    Object? stringField4 = $elAbsent,
    Object? numField,
    Object? numField2 = $elAbsent,
    Object? numField3,
    Object? numField4 = $elAbsent,
    Object? intField,
    Object? intField2 = $elAbsent,
    Object? intField3,
    Object? intField4 = $elAbsent,
    Object? doubleField,
    Object? doubleField2 = $elAbsent,
    Object? doubleField3,
    Object? doubleField4 = $elAbsent,
    Object? boolField,
    Object? boolField2 = $elAbsent,
    Object? boolField3,
    Object? boolField4 = $elAbsent,
    Object? listField,
    Object? listField2 = $elAbsent,
    Object? listStringField,
    Object? listStringField2 = $elAbsent,
    Object? listStringField3,
    Object? listStringField4 = $elAbsent,
    Object? listIntField,
    Object? listIntField2 = $elAbsent,
    Object? listIntField3,
    Object? listIntField4 = $elAbsent,
    Object? listDoubleField,
    Object? listDoubleField2 = $elAbsent,
    Object? listDoubleField3,
    Object? listDoubleField4 = $elAbsent,
    Object? setField,
    Object? setField2 = $elAbsent,
    Object? mapField,
    Object? mapField2 = $elAbsent,
    Object? userModel,
    Object? userModel2 = $elAbsent,
    Object? myAnimal,
    Object? myDog = $elAbsent,
    Object? animalList,
    Object? startDate = $elAbsent,
  }) {
    return TestModel(
      stringField: stringField == null
          ? this.stringField
          : stringField as String,
      stringField2: identical(stringField2, $elAbsent)
          ? this.stringField2
          : stringField2 as String?,
      stringField3: stringField3 == null
          ? this.stringField3
          : stringField3 as String,
      stringField4: identical(stringField4, $elAbsent)
          ? this.stringField4
          : stringField4 as String?,
      numField: numField == null ? this.numField : numField as num,
      numField2: identical(numField2, $elAbsent)
          ? this.numField2
          : numField2 as num?,
      numField3: numField3 == null ? this.numField3 : numField3 as num,
      numField4: identical(numField4, $elAbsent)
          ? this.numField4
          : numField4 as num?,
      intField: intField == null ? this.intField : intField as int,
      intField2: identical(intField2, $elAbsent)
          ? this.intField2
          : intField2 as int?,
      intField3: intField3 == null ? this.intField3 : intField3 as int,
      intField4: identical(intField4, $elAbsent)
          ? this.intField4
          : intField4 as int?,
      doubleField: doubleField == null
          ? this.doubleField
          : doubleField as double,
      doubleField2: identical(doubleField2, $elAbsent)
          ? this.doubleField2
          : doubleField2 as double?,
      doubleField3: doubleField3 == null
          ? this.doubleField3
          : doubleField3 as double,
      doubleField4: identical(doubleField4, $elAbsent)
          ? this.doubleField4
          : doubleField4 as double?,
      boolField: boolField == null ? this.boolField : boolField as bool,
      boolField2: identical(boolField2, $elAbsent)
          ? this.boolField2
          : boolField2 as bool?,
      boolField3: boolField3 == null ? this.boolField3 : boolField3 as bool,
      boolField4: identical(boolField4, $elAbsent)
          ? this.boolField4
          : boolField4 as bool?,
      listField: listField == null
          ? this.listField
          : listField as List<dynamic>,
      listField2: identical(listField2, $elAbsent)
          ? this.listField2
          : listField2 as List<dynamic>?,
      listStringField: listStringField == null
          ? this.listStringField
          : listStringField as List<String>,
      listStringField2: identical(listStringField2, $elAbsent)
          ? this.listStringField2
          : listStringField2 as List<String>?,
      listStringField3: listStringField3 == null
          ? this.listStringField3
          : listStringField3 as List<String>,
      listStringField4: identical(listStringField4, $elAbsent)
          ? this.listStringField4
          : listStringField4 as List<String>?,
      listIntField: listIntField == null
          ? this.listIntField
          : listIntField as List<int>,
      listIntField2: identical(listIntField2, $elAbsent)
          ? this.listIntField2
          : listIntField2 as List<int>?,
      listIntField3: listIntField3 == null
          ? this.listIntField3
          : listIntField3 as List<int>,
      listIntField4: identical(listIntField4, $elAbsent)
          ? this.listIntField4
          : listIntField4 as List<int>?,
      listDoubleField: listDoubleField == null
          ? this.listDoubleField
          : listDoubleField as List<double>,
      listDoubleField2: identical(listDoubleField2, $elAbsent)
          ? this.listDoubleField2
          : listDoubleField2 as List<double>?,
      listDoubleField3: listDoubleField3 == null
          ? this.listDoubleField3
          : listDoubleField3 as List<double>,
      listDoubleField4: identical(listDoubleField4, $elAbsent)
          ? this.listDoubleField4
          : listDoubleField4 as List<double>?,
      setField: setField == null ? this.setField : setField as Set<dynamic>,
      setField2: identical(setField2, $elAbsent)
          ? this.setField2
          : setField2 as Set<dynamic>?,
      mapField: mapField == null
          ? this.mapField
          : mapField as Map<String, dynamic>,
      mapField2: identical(mapField2, $elAbsent)
          ? this.mapField2
          : mapField2 as Map<String, dynamic>?,
      userModel: userModel == null
          ? this.userModel
          : this.userModel.merge(userModel as UserModel),
      userModel2: identical(userModel2, $elAbsent)
          ? this.userModel2
          : (userModel2 == null
                ? null
                : (this.userModel2 == null
                      ? userModel2 as UserModel
                      : this.userModel2!.merge(userModel2 as UserModel))),
      myAnimal: myAnimal == null
          ? this.myAnimal
          : this.myAnimal.merge(myAnimal as AnimalModel),
      myDog: identical(myDog, $elAbsent)
          ? this.myDog
          : (myDog == null
                ? null
                : (this.myDog == null
                      ? myDog as AnimalModel
                      : this.myDog!.merge(myDog as AnimalModel))),
      animalList: animalList == null
          ? this.animalList
          : animalList as List<AnimalModel>,
      startDate: identical(startDate, $elAbsent)
          ? this.startDate
          : startDate as DateTime?,
    );
  }

  TestModel merge([TestModel? other]) {
    if (other == null) return this;
    return TestModel(
      stringField: other.stringField,
      stringField2: other.stringField2 ?? stringField2,
      stringField3: other.stringField3,
      stringField4: other.stringField4 ?? stringField4,
      numField: other.numField,
      numField2: other.numField2 ?? numField2,
      numField3: other.numField3,
      numField4: other.numField4 ?? numField4,
      intField: other.intField,
      intField2: other.intField2 ?? intField2,
      intField3: other.intField3,
      intField4: other.intField4 ?? intField4,
      doubleField: other.doubleField,
      doubleField2: other.doubleField2 ?? doubleField2,
      doubleField3: other.doubleField3,
      doubleField4: other.doubleField4 ?? doubleField4,
      boolField: other.boolField,
      boolField2: other.boolField2 ?? boolField2,
      boolField3: other.boolField3,
      boolField4: other.boolField4 ?? boolField4,
      listField: other.listField,
      listField2: other.listField2 ?? listField2,
      listStringField: other.listStringField,
      listStringField2: other.listStringField2 ?? listStringField2,
      listStringField3: other.listStringField3,
      listStringField4: other.listStringField4 ?? listStringField4,
      listIntField: other.listIntField,
      listIntField2: other.listIntField2 ?? listIntField2,
      listIntField3: other.listIntField3,
      listIntField4: other.listIntField4 ?? listIntField4,
      listDoubleField: other.listDoubleField,
      listDoubleField2: other.listDoubleField2 ?? listDoubleField2,
      listDoubleField3: other.listDoubleField3,
      listDoubleField4: other.listDoubleField4 ?? listDoubleField4,
      setField: other.setField,
      setField2: other.setField2 ?? setField2,
      mapField: other.mapField,
      mapField2: other.mapField2 ?? mapField2,
      userModel: userModel.merge(other.userModel),
      userModel2: userModel2 == null
          ? other.userModel2
          : userModel2!.merge(other.userModel2),
      myAnimal: myAnimal.merge(other.myAnimal),
      myDog: myDog == null ? other.myDog : myDog!.merge(other.myDog),
      animalList: other.animalList,
      startDate: other.startDate ?? startDate,
    );
  }

  List<Object?> get _props => [
    stringField,
    stringField2,
    stringField3,
    stringField4,
    numField,
    numField2,
    numField3,
    numField4,
    intField,
    intField2,
    intField3,
    intField4,
    doubleField,
    doubleField2,
    doubleField3,
    doubleField4,
    boolField,
    boolField2,
    boolField3,
    boolField4,
    listField,
    listField2,
    listStringField,
    listStringField2,
    listStringField3,
    listStringField4,
    listIntField,
    listIntField2,
    listIntField3,
    listIntField4,
    listDoubleField,
    listDoubleField2,
    listDoubleField3,
    listDoubleField4,
    setField,
    setField2,
    mapField,
    mapField2,
    userModel,
    userModel2,
    myAnimal,
    myDog,
    animalList,
    startDate,
  ];
}
