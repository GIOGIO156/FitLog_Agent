import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_strings.dart';
import 'language_controller.dart';

extension LocalizationX on BuildContext {
  AppStrings get strings => AppStrings(watch<LanguageController>().language);

  AppStrings get stringsRead => AppStrings(read<LanguageController>().language);

  LanguageController get languageController => read<LanguageController>();
}
