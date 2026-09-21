import 'package:flame/game.dart';
import 'package:flutcraft/src/bootstrap/game_bootstrap.dart';
import 'package:flutcraft/src/game/flutcraft_game.dart';
import 'package:flutcraft/src/game/hud_state.dart';
import 'package:flutcraft/src/ui/hud.dart';
import 'package:flutcraft/src/save/file_save_storage.dart';
import 'package:flutcraft/src/save/repository_save_sink.dart';
import 'package:flutcraft/src/ui/providers/session_providers.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Na telefonie gra chodzi tylko poziomo - pionowy kadr obcina pole
/// widzenia i nie mieści sterowania dotykowego.
Future<void> _lockLandscape() async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockLandscape();
  runApp(FlutcraftApp(session: await _openSession()));
}

/// Continues the last game if there is one, and starts a new world if not.
Future<LoopGameSession> _openSession() async {
  final repository = SaveRepository(storage: await _openStorage());
  final sink = RepositorySaveSink(repository: repository);
  final saved = await _loadWorld(repository);

  return saved == null
      ? createSession(saveSink: sink)
      : restoreSession(saved, saveSink: sink);
}

/// Falls back to memory where there is no writable directory, so the game
/// still starts — it just forgets.
Future<SaveStorage> _openStorage() async {
  try {
    return await FileSaveStorage.open();
  } on Object catch (error) {
    debugPrint('No save directory available, playing without saves: $error');
    return InMemorySaveStorage();
  }
}

/// Reads the saved world, or `null` when there is none worth loading.
///
/// A save that cannot be read must not stop the game from starting: the
/// player gets a new world, and the old file is left on disk untouched in
/// case it can be recovered later.
Future<SaveData?> _loadWorld(SaveRepository repository) async {
  try {
    final result = await repository.load(kWorldSlot);
    for (final warning in result?.warnings ?? const <SaveWarning>[]) {
      debugPrint('Save warning: $warning');
    }
    return result?.data;
  } on Object catch (error) {
    debugPrint('Could not read the save, starting a new world: $error');
    return null;
  }
}

class FlutcraftApp extends StatelessWidget {
  const FlutcraftApp({required this.session, super.key});

  final LoopGameSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.t.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GameScreen(session: session),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({required this.session, super.key});

  final LoopGameSession session;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  LoopGameSession get _session => widget.session;
  late final FlutcraftGame _game = FlutcraftGame(session: _session);
  final FocusNode _focusNode = FocusNode();

  /// Saves when the app goes to the background — on a phone that is how most
  /// sessions end, and the autosave timer will not get another chance.
  late final AppLifecycleListener _lifecycle;

  /// Po przekroczeniu tego dystansu gest traktujemy jako rozglądanie
  /// i przerywamy rozpoczęte kopanie.
  static const double _lookThreshold = 14;

  late bool _touchControls = _isTouchPlatform;
  bool _help = false;

  int? _pointer;
  Offset _last = Offset.zero;
  double _travelled = 0;
  bool _looking = false;

  static bool get _isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _saveNow, onDetach: _saveNow);
  }

  void _saveNow() => _session.dispatch(const SaveGame());

  @override
  void dispose() {
    _lifecycle.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    // Gdy otwarty jest ekwipunek, świat nie reaguje na wskaźnik.
    if (_game.screen.pausesWorld) return;

    if (event.buttons & kSecondaryMouseButton != 0) {
      _game.interactOrPlace();
      return;
    }
    if (_pointer != null) return;

    _pointer = event.pointer;
    _last = event.position;
    _travelled = 0;
    _looking = false;
    _game.setMining(true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;

    final delta = event.position - _last;
    _last = event.position;
    _travelled += delta.distance;

    if (!_looking && _travelled > _lookThreshold) {
      _looking = true;
      _game.setMining(false);
    }
    if (_looking) _game.look(delta.dx, delta.dy);
  }

  void _endPointer(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _looking = false;
    _game.setMining(false);
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _game.screen.pausesWorld) return;
    _game.cycleSlot(event.scrollDelta.dy > 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [gameSessionProvider.overrideWithValue(_session)],
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GameWidget(
                game: _game,
                focusNode: _focusNode,
                autofocus: true,
              ),
            ),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: (e) => _endPointer(e.pointer),
                onPointerCancel: (e) => _endPointer(e.pointer),
                onPointerSignal: _onSignal,
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<HudSnapshot?>(
                valueListenable: _game.hud,
                builder: (context, snapshot, _) {
                  if (snapshot == null) {
                    return ColoredBox(
                      color: const Color(0xFF88BBEE),
                      child: Center(
                        child: Builder(
                          builder: (context) => Text(
                            context.t.loadingWorld,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  }
                  return Hud(
                    game: _game,
                    snapshot: snapshot,
                    showTouchControls: _touchControls,
                    helpVisible: _help,
                    onToggleTouchControls: () =>
                        setState(() => _touchControls = !_touchControls),
                    onToggleHelp: () => setState(() => _help = !_help),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
