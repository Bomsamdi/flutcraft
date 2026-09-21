/// Every widget in Flutcraft, and the providers behind them.
///
/// This package has no Flame and no flame_3d in its `pubspec`, so no widget
/// here *can* reach for a GPU resource — the compiler enforces it. That is
/// why the whole interface renders in `flutter test`.
library;

export 'src/atlas_image.dart';
export 'src/hud.dart';
export 'src/input/keyboard_input_source.dart';
export 'src/providers/engine_providers.dart';
export 'src/providers/message_provider.dart';
export 'src/providers/session_providers.dart';
export 'src/recipe_book.dart';
export 'src/screens.dart';
export 'src/slots.dart';
export 'src/widgets.dart';
