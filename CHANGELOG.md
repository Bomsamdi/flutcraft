# Changelog

Notable changes to Flutcraft. Episode tags (`ep-NN`) mark the state of the
repository at the end of each recorded episode.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Six-package monorepo: `flutcraft_domain`, `flutcraft_atlas`,
  `flutcraft_l10n`, `flutcraft_ui`, `flutcraft_engine` and `app/flutcraft`,
  with the dependency rules checked in CI.
- Localisation in English and Polish, with exhaustive mapping from domain
  enums to display names.
- Riverpod for state and dependency injection: the whole HUD, including every
  screen, renders in `flutter test` against a headless game loop.
- One input pipeline: `GameAction`, a rebindable `Keymap` and an
  `InputRouter` that blends keyboard, pointer and touch into one frame.
- A second on-screen stick for looking around, on the right of the screen
  where a gamepad puts it. Dragging the screen still works.
- Saving: the world is stored as a seed plus the blocks that differ from it,
  with a tolerant reader, autosave and a save when the app goes to the
  background. Version 2 splits a save into a world and a roster of players;
  version 1 files still open, and become a world with one player in them.
- `flutcraft_protocol`: sealed client and server messages with a JSON codec,
  ready for a server to speak. The world travels as a seed plus its edits.
- `tool/check_layering.dart`, `tool/check_english.dart` and
  `tool/check_platform_config.dart`, all wired into CI.

### Fixed

- Mobs no longer walk inside the player. Bodies push each other apart, and a
  melee mob stops where the two boxes touch instead of pressing on — you can
  see what is hitting you, and swing at it.

### Changed

- The simulation is pure Dart and runs without Flutter, Flame or a GPU.
- `ItemStack` is immutable, which is what makes a snapshot a snapshot and
  removed the hand-maintained revision counter.
- Mob behaviour is a strategy per species rather than branches inside `Mob`.
- Mobs and arrows are synced to their components through one generic
  `EntitySync` instead of a pair of hand-written maps each.
