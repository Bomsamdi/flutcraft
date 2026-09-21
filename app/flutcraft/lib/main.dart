import 'package:flame/game.dart';
import 'package:flutcraft/src/bootstrap/game_bootstrap.dart';
import 'package:flutcraft/src/game/flutcraft_game.dart';
import 'package:flutcraft/src/game/hud_state.dart';
import 'package:flutcraft/src/ui/hud.dart';
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
  runApp(const FlutcraftApp());
}

class FlutcraftApp extends StatelessWidget {
  const FlutcraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.t.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LoopGameSession _session = createSession();
  late final FlutcraftGame _game = FlutcraftGame(session: _session);
  final FocusNode _focusNode = FocusNode();

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
  void dispose() {
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
