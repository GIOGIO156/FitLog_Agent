import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  runApp(FitLogApp(config: config));
}
