import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutcraft/src/bootstrap/game_bootstrap.dart';
import 'package:flutcraft_engine/flutcraft_engine.dart';
import 'package:flutcraft_ui/flutcraft_ui.dart';
import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft/src/save/file_save_storage.dart';
import 'package:flutcraft/src/net/web_socket_channel.dart';
import 'package:flutcraft/src/save/repository_save_sink.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// On a phone the game only runs sideways: a portrait frame crops the field
/// of view and leaves no room for the touch controls.
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
  // The atlas is built before the game starts: the HUD has its icons from
  // the first frame, and the engine is handed a resource instead of making it.
  final atlas = TextureAtlas.generate();
  runApp(
    FlutcraftApp(
      session: await _openSession(),
      atlas: atlas,
      atlasImage: await decodeAtlasImage(atlas),
    ),
  );
}

/// Where to play: a server if one was named, otherwise this machine.
///
/// A compile-time define rather than a setting, because the season has not
/// built a server browser yet and a hidden knob is more honest than a menu
/// with one entry in it:
///
/// ```
/// flutter run --dart-define=FLUTCRAFT_SERVER=ws://192.168.1.10:8787
/// ```
const _serverAddress = String.fromEnvironment('FLUTCRAFT_SERVER');

/// Who this client says it is.
///
/// Fixed for now. It belongs on disk beside the save, so that reconnecting
/// finds the same inventory rather than a new player standing beside the old
/// one's belongings.
const _playerId = PlayerId('player');

/// Opens a game: on a server if one was named, otherwise on this machine.
Future<PlayableSession> _openSession() async {
  if (_serverAddress.isNotEmpty) {
    return RemoteGameSession.join(
      await WebSocketChannel.connect(Uri.parse(_serverAddress)),
      _playerId,
    );
  }
  return _openLocalSession();
}

/// Continues the last game if there is one, and starts a new world if not.
Future<LoopGameSession> _openLocalSession() async {
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
  const FlutcraftApp({
    required this.session,
    required this.atlas,
    required this.atlasImage,
    super.key,
  });

  final PlayableSession session;
  final TextureAtlas atlas;
  final ui.Image atlasImage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.t.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GameScreen(session: session, atlas: atlas, atlasImage: atlasImage),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.session,
    required this.atlas,
    required this.atlasImage,
    super.key,
  });

  final PlayableSession session;
  final TextureAtlas atlas;
  final ui.Image atlasImage;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PlayableSession get _session => widget.session;

  /// Every input source pushes into this one router; the game reads the
  /// finished frame. Created here because touch and pointer live in Flutter,
  /// not in the engine.
  final InputRouter _input = InputRouter();
  late final KeyboardInputSource _keyboard = KeyboardInputSource(
    router: _input,
  );
  late final FlutcraftGame _game = FlutcraftGame(
    session: _session,
    input: _input,
    atlas: EngineAtlas(widget.atlas),
  );
  final FocusNode _focusNode = FocusNode();

  /// Saves when the app goes to the background — on a phone that is how most
  /// sessions end, and the autosave timer will not get another chance.
  late final AppLifecycleListener _lifecycle;

  /// Past this distance a drag counts as looking around, and whatever mining
  /// it started is called off.
  static const double _lookThreshold = 14;

  /// Radians per pixel of pointer movement.
  static const double _lookSensitivity = 0.0032;

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
    // While a screen is open the world ignores the pointer.
    if (_session.snapshot.route.pausesWorld) return;

    if (event.buttons & kSecondaryMouseButton != 0) {
      _session.dispatch(const UseOrPlace());
      return;
    }
    if (_pointer != null) return;

    _pointer = event.pointer;
    _last = event.position;
    _travelled = 0;
    _looking = false;
    _input.press(GameAction.primary);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;

    final delta = event.position - _last;
    _last = event.position;
    _travelled += delta.distance;

    if (!_looking && _travelled > _lookThreshold) {
      _looking = true;
      _input.release(GameAction.primary);
    }
    if (_looking) {
      _input.look(-delta.dx * _lookSensitivity, -delta.dy * _lookSensitivity);
    }
  }

  void _endPointer(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _looking = false;
    _input.release(GameAction.primary);
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (_session.snapshot.route.pausesWorld) return;
    _session.dispatch(CycleHotbarSlot(event.scrollDelta.dy > 0 ? 1 : -1));
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        gameSessionProvider.overrideWithValue(_session),
        inputRouterProvider.overrideWithValue(_input),
        atlasImageProvider.overrideWithValue(widget.atlasImage),
        frameStatsProvider.overrideWithValue(_game.frameStats),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
            // Keys are read here rather than inside the engine: the engine
            // must not know what a keyboard is, only what an action is.
            Positioned.fill(
              child: KeyboardListener(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: (_) => _keyboard.onKeysChanged(
                  HardwareKeyboard.instance.logicalKeysPressed,
                ),
                child: const SizedBox.expand(),
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
              child: Hud(
                showTouchControls: _touchControls,
                helpVisible: _help,
                onToggleTouchControls: () =>
                    setState(() => _touchControls = !_touchControls),
                onToggleHelp: () => setState(() => _help = !_help),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
