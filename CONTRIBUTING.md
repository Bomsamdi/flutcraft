# Contributing

Flutcraft is the codebase for a tutorial series, so it has one unusual goal on
top of working: **it has to read well**. A clever line that needs a paragraph
of explanation on video is worse here than a plain one that needs none.

## Getting set up

```bash
flutter pub get          # a pub workspace: one resolve for every package
melos run test           # or `flutter test` inside a package
```

[melos](https://melos.invertase.dev) is only a task runner here; the
dependency resolution is done by the pub workspace at the repository root.

## Before you open a pull request

```bash
dart format .
flutter analyze --fatal-infos --fatal-warnings
melos run test
dart run tool/check_layering.dart
dart run tool/check_english.dart
dart run tool/check_platform_config.dart
```

CI runs all of these. They are fast; running them locally is faster than
waiting for the red X.

## Where code goes

The dependency graph is in the [README](README.md), and
`tool/check_layering.dart` enforces it. In short:

- **Simulation** — anything that decides what happens in the game — belongs in
  `flutcraft_domain`, in plain Dart. If you reach for `BuildContext`, you are
  in the wrong package.
- **Widgets and providers** go in `flutcraft_ui`. If a widget needs the GPU,
  the design is wrong: the interface renders from a snapshot.
- **Anything with a mesh, a texture or a camera** goes in `flutcraft_engine`.
- **Platform code** — files, permissions, `path_provider` — lives in
  `app/flutcraft`, behind a port defined in the domain.

New code is written in the shape the series teaches, not in a shape a later
episode has to undo.

## Tests

Every change to behaviour comes with a test, and the test is named after the
behaviour rather than the method. `'a dead mob is not a target'` says what
broke when it fails; `'testTargetPicker3'` does not.

Tests and running the game catch different things. Tests here have caught a
crash on negative pattern indices, a furnace losing its last fuel cycle, and a
creeper exploding several times in one frame. Running the game caught an
initialisation order bug and a held item that stopped being drawn — neither
was reachable from a test, because both involve GPU resources. Do both.

## Language

The code, the comments and the test names are in English, because the videos
are. The only Polish in the repository is in `flutcraft_l10n`, where it is the
product. `tool/check_english.dart` checks this; a test that must assert a
Polish string marks that line with `// polish-ok`.

User-facing text never appears as a literal in a widget. It goes into
`app_en.arb`, gets a Polish translation in `app_pl.arb`, and reaches the
screen through `context.t` or `context.strings`. A new `GameEvent`, block,
item or mob will not compile until it has a name in both languages — the
switches in `GameStrings` are exhaustive on purpose.

## Commits

Conventional Commits, and the body explains **why**, not what. The diff
already says what changed. A commit here doubles as a chapter marker for an
episode, so `git log --oneline ep-06..ep-07` should read like a table of
contents.

## Episode tags

Tags `ep-NN` and branches `episode/NN-title` are **immutable**: viewers clone
them. A mistake in a published episode is fixed with `ep-NN.1`, never with a
force push.
