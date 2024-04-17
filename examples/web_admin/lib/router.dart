import 'package:flutter_base/flutter_base.dart';
import 'package:web_admin/pages/home.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
  ],
);
