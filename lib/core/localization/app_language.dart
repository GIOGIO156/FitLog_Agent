enum AppLanguage { english, chinese }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.chinese:
        return 'zh';
    }
  }

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'zh':
        return AppLanguage.chinese;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}
