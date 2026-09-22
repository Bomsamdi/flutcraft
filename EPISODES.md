# Episodes

Every episode ends at a tag. `ep-NN` is the state of the repository when
that video ends, and the tags are immutable — a mistake in a published
episode is fixed with `ep-NN.1`, never with a force push.

```bash
git checkout ep-07          # the repository as episode 7 leaves it
git log --oneline ep-06..ep-07   # what that episode changed, commit by commit
```

| # | Episode | Commits |
|---|---|---|
| 01 | [A Voxel Prototype, Warts and All](#ep-01) | 1 |
| 02 | [A Workspace, Not a Folder](#ep-02) | 2 |
| 03 | [A Domain With a Guard on the Door](#ep-03) | 2 |
| 04 | [Types That Make Bad States Unsayable](#ep-04) | 2 |
| 05 | [Data Instead of Branches](#ep-05) | 3 |
| 06 | [Values That Do Not Change Under Your Hand](#ep-06) | 2 |
| 07 | [The First Systems Leave the God Object](#ep-07) | 3 |
| 08 | [Mobs, Arrows, Furnaces, and the Last Two Loops](#ep-08) | 2 |
| 09 | [The Whole Game Without a GPU](#ep-09) | 3 |
| 10 | [A Snapshot, and a HUD That Renders in a Test](#ep-10) | 3 |
| 11 | [A Composition Root](#ep-11) | 2 |
| 12 | [Two Languages, One Exhaustive Switch](#ep-12) | 3 |
| 13 | [Checks That Run Themselves](#ep-13) | 1 |
| 14 | [The World in a Seed and a Few Hundred Edits](#ep-14) | 2 |
| 15 | [One Input Pipeline](#ep-15) | 1 |
| 16 | [Six Packages, and a Language Rule](#ep-16) | 2 |
| 17 | [One Generic for Entity Sync](#ep-17) | 2 |
| 18 | [Coverage, and Text That Cannot Be Translated](#ep-18) | 2 |
| 19 | [Making Melos Actually Work](#ep-19) | 1 |
| 20 | [A Second Stick for Looking](#ep-20) | 1 |
| 21 | [Mobs That Do Not Walk Inside You](#ep-21) | 1 |
| 22 | [One World, Many Players](#ep-22) | 3 |
| 23 | [A Fixed Timestep](#ep-23) | 1 |
| 24 | [Events With an Addressee](#ep-24) | 1 |
| 25 | [A Protocol Both Ends Share](#ep-25) | 1 |
| 26 | [A Save With a Roster](#ep-26) | 1 |
| 27 | [An Authoritative Loop in Plain Dart](#ep-27) | 1 |
| 28 | [The Renderer Stops Assuming](#ep-28) | 1 |
| 29 | [Who Owns What](#ep-29) | 1 |
| 30 | [The Client That Doesn't Know It's Remote](#ep-30) | 1 |
| 31 | [The App Joins a Server](#ep-31) | 1 |
| 32 | [Shipping a Server](#ep-32) | 1 |
| 33 | [Mobs on a Leash](#ep-33) | 1 |
| 34 | [The Bug Only the Container Could Show](#ep-34) | 1 |
| 35 | [Registration and Login](#ep-35) | 1 |
| 36 | [Three Bugs You Only Find by Playing](#ep-36) | 3 |
| 37 | [Before the First Video](#ep-37) | 2 |

### ep-01

**A Voxel Prototype, Warts and All**

Where the series starts: a game that works, a class of 918 lines with 21 responsibilities and no test covering any of them.

### ep-02

**A Workspace, Not a Folder**

Taking Vector3 from vector_math instead of a 3D engine, and turning the repository into a pub workspace with melos as a task runner.

### ep-03

**A Domain With a Guard on the Door**

flutcraft_domain has no Flutter in its pubspec, so the compiler forbids it — and a script checks the boundary a lint cannot see across.

### ep-04

**Types That Make Bad States Unsayable**

A packed integer key becomes BlockPos; two nullable fields become a sealed hierarchy with three variants and an exhaustive switch.

### ep-05

**Data Instead of Branches**

One LootTable for blocks and mobs, a registry of interactive blocks, and a strategy per species — three ladders of ifs turned into tables.

### ep-06

**Values That Do Not Change Under Your Hand**

An immutable ItemStack retires a hand-kept revision counter, and a sealed GameEvent gets the last strings out of the simulation.

### ep-07

**The First Systems Leave the God Object**

Mining, placement and explosions move into the domain and become testable for the first time in the project.

### ep-08

**Mobs, Arrows, Furnaces, and the Last Two Loops**

The remaining simulation loops leave the engine. The god object is down to 790 lines.

### ep-09

**The Whole Game Without a GPU**

GameCommand replaces twenty-five public methods and GameLoop ticks eight systems. A test runs a thousand frames in milliseconds.

### ep-10

**A Snapshot, and a HUD That Renders in a Test**

A snapshot of values, Riverpod providers, and the whole HUD mounted over a real game with no GPU in sight.

### ep-11

**A Composition Root**

The world is built before the engine starts, and the engine is handed a finished session. Plus the bug that only running the game could show.

### ep-12

**Two Languages, One Exhaustive Switch**

English and Polish from ARB, and switches that will not compile until a new block, item or mob has a name in both.

### ep-13

**Checks That Run Themselves**

Eight CI jobs, and a platform-configuration guard for the flags without which the game does not start.

### ep-14

**The World in a Seed and a Few Hundred Edits**

Saving as a seed plus the differences, with a tolerant reader, autosave, and an adapter that cannot leave half a file behind.

### ep-15

**One Input Pipeline**

A key stops being something the game compares: sources produce actions, one router blends them, one function says what an action means where.

### ep-16

**Six Packages, and a Language Rule**

The atlas, the engine and the interface split out — and the whole codebase goes into English with a gate to keep it there.

### ep-17

**One Generic for Entity Sync**

Two hand-written maps of components become five lines of declaration, and the game class falls to 159 lines.

### ep-18

**Coverage, and Text That Cannot Be Translated**

Thresholds per package with the reason for each, and a gate that catches a literal string on its way to the screen.

### ep-19

**Making Melos Actually Work**

The documented command did not work: melos 7 wants its configuration in the root pubspec and itself as a dev dependency.

### ep-20

**A Second Stick for Looking**

A stick is a speed, not a displacement — and the touch controls were rendering in the corner of the sky the whole time.

### ep-21

**Mobs That Do Not Walk Inside You**

Bodies push each other apart, and a melee mob stops where the two boxes touch instead of pressing on.

### ep-22

**One World, Many Players**

A spike, and what it found: systems that looked stateless held state per player, and a spawner that bred faster the more people were in the world.

### ep-23

**A Fixed Timestep**

The same second of walking, delivered as 60, 30 or 6 frames, has to end in the same place. Nothing networked can be built until it does.

### ep-24

**Events With an Addressee**

Only the simulation knows whose blow produced which event, so that is where the addressee is decided.

### ep-25

**A Protocol Both Ends Share**

Sealed messages and a JSON codec, with the traps: an enum by index, and jsonEncode writing 0.0 as 0.

### ep-26

**A Save With a Roster**

A world and its players are written apart, because they change to different rhythms — and version 1 still opens.

### ep-27

**An Authoritative Loop in Plain Dart**

A world over WebSockets in dart:io, a bounded outbound queue that knows what it may drop, and a test against the compiled binary.

### ep-28

**The Renderer Stops Assuming**

A renderer needs a live world, and saying so is what stops it falling over the moment a second player joins.

### ep-29

**Who Owns What**

Two loops, one that decides and one that predicts, differing only in the systems they are given.

### ep-30

**The Client That Doesn't Know It's Remote**

Prediction, reconciliation paid off over five ticks, an entity mirror that writes into existing objects, and blocks predicted for the eye only.

### ep-31

**The App Joins a Server**

One --dart-define and the same app plays locally or on a server. Plus a macOS sandbox that refuses the socket without a word about sandboxes.

### ep-32

**Shipping a Server**

A world that lasts, a two-stage image, and an ENTRYPOINT in exec form — without which SIGTERM never arrives and every deploy loses a minute.

### ep-33

**Mobs on a Leash**

Aggro range measured to the player never runs out. Measured: 67.9 blocks of drag without a leash, 32.1 with one.

### ep-34

**The Bug Only the Container Could Show**

Docker made the volume root-owned, the server ran as somebody else, and the first player to leave took the process down.

### ep-35

**Registration and Login**

PBKDF2 with a salt per account, hashed on an isolate so a sign-in never stops the world, and a screen instead of a compile-time name.

### ep-36

**Three Bugs You Only Find by Playing**

A cached bounding box, a burst of input frames overwritten, and a server aiming a tick behind the crosshair.

### ep-37

**Before the First Video**

What a readiness pass turns up: CI off the push path, the limits of the network code written down, and a history cut into episodes.
