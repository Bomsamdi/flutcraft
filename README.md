# Flutcraft

A voxel game written in Flutter with [`flame_3d`](https://pub.dev/packages/flame_3d)
(Flutter GPU / Impeller), built step by step in a public tutorial series.
Everything runs locally: no server, no network, and not a single asset file —
every texture in the game is painted in code at startup.

![CI](https://github.com/OWNER/flutcraft/actions/workflows/ci.yml/badge.svg)

> **Not affiliated with Mojang or Microsoft.** This is an independent
> educational project. It borrows the idea of a block world, not its assets:
> all textures are generated procedurally in Dart, and no Minecraft code,
> art or trademark is used here.

## Quick start

```bash
git clone <this repo> && cd flutcraft
flutter pub get
flutter run -d macos        # or -d <device-id>
```

Needs Flutter 3.44+ and Impeller, so it runs on macOS, iOS and Android
(Vulkan). On the web, `flame_3d` uses WebGPU and needs a browser with WebGPU
enabled.

To follow the series, check out the tag for an episode and run it:

```bash
git checkout ep-07 && flutter run -d macos
```

Every tag is a working game. Generated files are committed for exactly that
reason.

## Architecture

Six packages, with the dependency rules enforced by the compiler rather than
by good intentions.

```
                  flutcraft_domain   (pure Dart — no Flutter)
                 /     /      |       \
 flutcraft_protocol   /       |     flutcraft_l10n
                     /        |       /
      flutcraft_atlas     flutcraft_ui    (Flutter + Riverpod, no flame)
                              |
         flutcraft_engine (flame_3d) ───┐
                              |         |
                         app/flutcraft ─┘
```

| Package | Contains |
|---|---|
| `flutcraft_domain` | Blocks, items, inventory, crafting, world, physics, actors, the simulation systems, the input model and the save format. |
| `flutcraft_atlas` | The procedural texture atlas: 45 tiles painted pixel by pixel, plus the UV table. |
| `flutcraft_l10n` | ARB files for English and Polish, and the mapping from domain enums to names. |
| `flutcraft_ui` | Every widget and every Riverpod provider. |
| `flutcraft_engine` | Meshing, chunk streaming, mob models and the Flame game that drives the loop. |
| `flutcraft_protocol` | What a client and a server say to each other, and how it is spelled. No sockets: a message decodes in a test that opens nothing. |
| `flutcraft_server` | An authoritative world over WebSockets, in plain `dart:io`. Compiles to one self-contained binary. |
| `app/flutcraft` | The composition root, the platform folders and the save file adapter. |

**Three rules do most of the work:**

1. **`flutcraft_domain` has no Flutter in its `pubspec`**, so the compiler
   forbids importing one. Its tests run under `dart test` in seconds.
2. **`flutcraft_ui` has no `flame_3d`**, so no widget *can* touch a GPU
   resource. Every screen renders in `flutter test`.
3. **`flutcraft_engine` cannot see `flutcraft_ui` or `flutcraft_l10n`**, so the
   engine never formats a sentence. It emits events; the interface finds the
   words.

Lints cannot see across package borders, so the rules are checked by
`dart run tool/check_layering.dart` in CI. Break one and the build fails.

## What the game has

| Area | How it works |
|---|---|
| World | 128 × 48 × 128 voxels, generated from value noise and fBm |
| Terrain | Hills, beaches, soil and stone layers, coal and iron ore, gravel, trees |
| Rendering | One mesh per 16×16 chunk, faces between solid blocks culled |
| Textures | An atlas generated in code, 16×16 px per tile, nearest filtering |
| Lighting | Face shading baked into the atlas, so the world is one unlit material |
| Movement | AABB collision against the grid, gravity, jumping, sprinting, flight |
| Aiming | A DDA raycast (Amanatides & Woo) out to 5.5 blocks |
| Mining | Progress depends on block hardness and tool tier |
| Inventory | 9 hotbar slots and 27 backpack slots, stacks of 64, splitting |
| Crafting | 2×2 in the inventory, 3×3 at a table, shaped and shapeless recipes |
| Furnace | Input, fuel and output, with a progress bar and a glowing block |
| Mobs | Zombie, skeleton, spider and creeper, each with its own behaviour |
| Combat | Hit mobs with the mining button, hearts, knockback, death, respawn |
| Saving | Seed plus edits, written as JSON; autosave and save on backgrounding |

### Crafting

The recipes follow the original, including sliding the pattern around the
grid: a pickaxe laid out in the bottom-right corner of a 3×3 still works.

| Result | Recipe | Where |
|---|---|---|
| 4 planks | a log, any cell | inventory |
| 4 sticks | planks above planks | inventory |
| Crafting table | 2×2 planks | inventory |
| Furnace | 8 cobble in a 3×3 ring | table |
| Pickaxe | 3 of the material in a row, 2 sticks below | table |
| Sword | 2 of the material stacked, a stick below | table |
| 4 arrows | ingot, stick, string | table |

The game has an in-game **recipe book** (`B`, or the book icon) that shows
every layout, marks in green what you can make right now, and lists what the
furnace accepts. Bricks have no recipe — they come from smelting sand.

### Splitting stacks

As in the original: with an **empty hand**, right-click (or a long press on a
phone) takes **half a stack**, rounding up. With **something in hand**, the
same gesture puts down **one item at a time**, so eight planks can be split
into any portions you like.

## Controls

| Input | Action |
|---|---|
| `W` `S` `A` `D` / left stick | Walk |
| Right stick (touch) / mouse or finger drag | Look around |
| Hold / `MINE` button | Mine and attack |
| Right click / `R` / `USE` | Place a block, use a table or furnace |
| `1`–`9`, a slot, the scroll wheel | Select an item |
| `E` / backpack icon | Inventory and crafting |
| `B` / book icon | Recipe book |
| Right click or long press on a slot | Split a stack |
| `Esc` | Close a screen |
| `Space` / `JUMP` | Jump; ascend while flying |
| `Shift` | Sprint; descend while flying |
| `F` / `FLY` | Toggle flight |
| `F5` | Save now |
| Arrow keys | Look around with the keyboard |

On a touch screen the controls are laid out like a gamepad: the left stick
walks, the right stick turns. Dragging the screen still looks around, but a
drag has to end at the edge of the screen, so turning right around took four
of them.

Keys are bound in one table (`defaultKeymap`); nothing in the simulation
compares a key code.

## Screen orientation

On phones and tablets the game runs **landscape only** — a portrait frame
crops the field of view and leaves no room for the touch controls. The lock is
set natively in `Info.plist` and `AndroidManifest.xml`, and confirmed from
Dart in `main()`; `tool/check_platform_config.dart` fails the build if one of
the three drifts. Inventory screens switch to a compact layout below 480 px of
height.

## Development

```bash
dart run tool/check_layering.dart     # package boundaries
dart run tool/check_english.dart      # the source reads in English
dart run tool/check_platform_config.dart
melos run test --no-select            # every package
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the repository is organised and
what a change is expected to come with.

## Running a server

```bash
dart run packages/flutcraft_server/bin/server.dart \
  --port 8787 --seed 1337 --world ./world
# or, as it ships:
dart compile exe packages/flutcraft_server/bin/server.dart -o flutcraft-server
./flutcraft-server --world ./world
```

`--world` is the directory the world is kept in: one file for the terrain and
one per player. Without it the server keeps everything in memory and the world
goes when the process does. With it, the world is written every minute and
again on `SIGTERM`, and `--seed` is ignored once a world exists there.

One world, many players, no dependencies beyond `dart:io`. To play on it:

```bash
cd app/flutcraft
flutter run -d macos --dart-define=FLUTCRAFT_SERVER=ws://127.0.0.1:8787
```

The define only fills in the address field. The game asks who you are before
it joins: a name of 3 to 16 letters, digits, dashes or underscores, and a
password of at least 6 characters. **Create account** claims a name,
**Log in** proves it, and the name is what the world remembers your
belongings by. One build is therefore enough for two players on one machine —
open it twice and sign in as two people.

Accounts are kept in `accounts.json` beside the world, as a PBKDF2-HMAC-SHA256
hash with a salt each. The password itself travels as typed, so anything
beyond a trusted network wants a `wss://` proxy in front of the server; that
is the transport's job and not the protocol's.

The client simulates its own player straight away and corrects itself against
the server; everything else in the world — mobs, arrows, other people — is
mirrored and interpolated. Nothing above `GameSession` knows the difference.

### In a container

```bash
docker build -t flutcraft-server .
docker run -p 8787:8787 -v flutcraft-world:/world flutcraft-server --seed 1337
```

The image is Debian rather than `scratch`, because `dart compile exe` embeds
the Dart runtime but still links against the host's libc. Mount something over
`/world` or the world goes with the container. Arguments after the image name
are passed to the server.

Dart does not cross-compile: the image has to be built on the architecture it
runs on, or with `docker build --platform linux/amd64` on a machine that can
emulate one.

## Known limits

- No transparency, so no water and no glass — that needs sorting and a second
  pass with alpha blending.
- Tools never wear out, and there is no day cycle, so mobs never stop.
- Broken blocks and mob drops go straight to the inventory; nothing lies on
  the ground.
- Mobs do not path around obstacles; they jump at them or get stuck.
- The world is finite and held entirely in memory.
- Chunk meshes are built on the UI thread, two per frame, with no isolates.
- A save stores the seed and the edits, so changing the terrain generator
  invalidates older saves. The format carries a `terrainVersion` for that.
- A password travels as typed. On anything wider than a trusted network the
  server belongs behind a `wss://` proxy, which is the transport's job and not
  the protocol's.
- The server checks that a claimed block is there and within reach, but not
  that the player can see it: a client could mine the far side of a wall it is
  standing against. Stopping that costs a second ray per player per tick, and
  the trade has not been worth making yet.
- Two copies of the game on one machine share one `client.json`, so the name
  they offer next time is whoever signed in last. It is a suggestion in a text
  field, not a login.

## Impeller

`flutter_gpu`, and therefore `flame_3d`, only runs on Impeller. It is the
default on iOS and Android; on macOS with Flutter 3.44 it has to be switched
on, which this repo does with `FLTEnableImpeller` in
`macos/Runner/Info.plist`.

## Licence

MIT — see [LICENSE](LICENSE).
