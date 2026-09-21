import 'package:flutter/widgets.dart';

import 'game_strings.dart';
import 'generated/app_localizations.dart';

/// Convenience access to translations from a widget.
extension GameStringsContext on BuildContext {
  /// Raw generated translations.
  AppLocalizations get t => AppLocalizations.of(this);

  /// Translations plus the mapping from domain enums to display names.
  GameStrings get strings => GameStrings(AppLocalizations.of(this));
}
