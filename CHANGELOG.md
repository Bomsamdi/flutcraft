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
- `flutcraft_server`: an authoritative world over WebSockets that compiles to
  a 6 MB self-contained binary. Two players can join one world and see each
  other move.
- A networked client: `RemoteGameSession` predicts its own movement, corrects
  itself against the server and mirrors everything else. The app joins a
  server with `--dart-define=FLUTCRAFT_SERVER=ws://host:port`.
- Accounts: a player registers a name with a password and signs in with it,
  on a screen in the game rather than through a compile-time define. One
  build now runs as two players on one machine. Secrets are stored as
  PBKDF2-HMAC-SHA256 with a salt each, checked on an isolate so that a
  sign-in never stops the world for everybody else.
- A server image: a two-stage `Dockerfile` that compiles the binary and ships
  it on `debian-slim` as a non-root user, with the world on a volume. CI
  builds it, puts up a building, restarts the container and checks the
  building is still standing.
- `--world <dir>` keeps a server's world on disk: written every minute and on
  `SIGTERM`, reloaded on start, with each player's belongings in their own
  file so an autosave cannot overwrite somebody else's.
- `tool/check_layering.dart`, `tool/check_english.dart` and
  `tool/check_platform_config.dart`, all wired into CI.

### Fixed

- Mobs no longer walk inside the player. Bodies push each other apart, and a
  melee mob stops where the two boxes touch instead of pressing on — you can
  see what is hitting you, and swing at it.
- Other players are drawn facing where they are actually looking. A client
  sends one input frame per simulation step and a socket delivers several of
  them at once; the server kept only the last of each burst. Axes survived
  that, being states, but a turn and a tap are amounts, and those were lost —
  and because nothing corrects a client about its own view, the two never
  agreed again. Frames are merged now: states from the newer, taps kept, turns
  added up.
- Other players and mobs no longer walk about as a pair of arms and legs.
  flame_3d invalidates a child's world transform when its parent moves, but
  not the child's cached bounding box — and that box is what decides whether
  the part is on screen. Limbs got away with it because setting a rotation
  every frame invalidates the box as a side effect; a head and a torso do not
  swing, so they were culled as if the figure had never left its spawn.
- A socket adapter no longer throws when a frame arrives while the connection
  is closing: the listener still fires after the stream behind it is closed.
- Joining a server no longer arrives empty-handed. The client waited for the
  welcome on one subscription and listened for the rest on another, and a
  broadcast stream keeps nothing for whoever is not listening yet — the
  inventory, sent immediately behind the welcome, fell into the gap.

### Changed

- `Hello` is gone from the protocol, and `SignIn`/`SignUp` take its place: a
  name anybody could claim was a label, not an account.
- Mobs chase on a leash. Aggro range is measured to the player and so never
  runs out while the player walks away, which left a tail of every mob that
  ever noticed you. A mob now remembers where its chase began, gives up
  thirty-two blocks from there and walks back; hit it on the way and it turns
  round. Mobs left far from everybody are retired, so the population cap does
  not fill up with stranded ones.
- The simulation is pure Dart and runs without Flutter, Flame or a GPU.
- `ItemStack` is immutable, which is what makes a snapshot a snapshot and
  removed the hand-maintained revision counter.
- Mob behaviour is a strategy per species rather than branches inside `Mob`.
- Mobs and arrows are synced to their components through one generic
  `EntitySync` instead of a pair of hand-written maps each.
