part of flutter_base;

const Uuid uuid = Uuid();

String get uuidStr => uuid.v4().replaceAll('-', '');
