import 'package:locara_app/gen/strings.g.dart';

Future<void> initI18n() async {
  // Register default plural resolver
  for (final locale in AppLocale.values) {
    if (locale == AppLocale.en) {
      continue;
    }

    await LocaleSettings.setPluralResolver(
      locale: locale,
      cardinalResolver: (n, {zero, one, two, few, many, other}) {
        if (n == 0) {
          return zero ?? other ?? n.toString();
        }
        if (n == 1) {
          return one ?? other ?? n.toString();
        }
        return other ?? n.toString();
      },
      ordinalResolver: (n, {zero, one, two, few, many, other}) {
        return other ?? n.toString();
      },
    );
  }
}

extension AppLocaleExt on AppLocale {
  /// The name of the locale in its own language.
  String getLocaleName() {
    return switch (this) {
      AppLocale.fa => 'فارسی',
      AppLocale.en => 'English',
    };
  }
}
