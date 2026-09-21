# Flutcraft

Prototyp Minecrafta we Flutterze na `flame_3d` (Flutter GPU / Impeller). Wszystko
działa lokalnie — bez serwera, bez sieci, bez assetów na dysku.

## Orientacja ekranu

Na telefonie i tablecie gra chodzi **wyłącznie poziomo** — pionowy kadr obcina
pole widzenia i nie mieści sterowania dotykowego. Blokada jest ustawiona
natywnie (`UISupportedInterfaceOrientations` w `ios/Runner/Info.plist`,
`android:screenOrientation="sensorLandscape"` w `AndroidManifest.xml`), a
`SystemChrome.setPreferredOrientations` w `main()` domyka sprawę po stronie
Fluttera. Ekrany ekwipunku przełączają się w tryb kompaktowy poniżej 480 px
wysokości, żeby zmieścić się bez przewijania. Na desktopie i w przeglądarce
okno zachowuje się normalnie.

## Uruchomienie

```bash
flutter run -d macos     # albo -d <id-urządzenia>
```

Wymaga Impellera, więc działa na macOS, iOS i Androidzie (Vulkan). Na Web
`flame_3d` korzysta z WebGPU, co wymaga przeglądarki z włączonym WebGPU.

## Co jest w prototypie

| Element | Realizacja |
|---|---|
| Świat | 128 × 48 × 128 wokseli, generowany proceduralnie (value noise + fBm) |
| Teren | wzgórza, plaże, warstwy ziemi i kamienia, rudy węgla i żelaza, żwir, drzewa |
| Renderowanie | siatka budowana per chunk 16×16, odcinane są ściany między blokami |
| Tekstury | atlas generowany w kodzie, 16×16 px na kafelek, filtrowanie `nearest` |
| Oświetlenie | cieniowanie ścian wypalone w atlasie → jeden `UnlitMaterial` na cały świat |
| Ruch | kolizje AABB z siatką, grawitacja, skok, sprint, tryb latania |
| Celowanie | raycast DDA (Amanatides & Woo) na 5,5 bloku, czarna ramka na celu |
| Niszczenie | postęp zależny od twardości bloku i poziomu narzędzia |
| Stawianie | blok z aktywnego slotu, z blokadą stawiania w sobie i w potworze |
| Ekwipunek | 9 slotów paska + 27 plecaka, stosy po 64, przekładanie i dzielenie stosów |
| Crafting | siatka 2×2 w ekwipunku, 3×3 przy stole, przepisy kształtowe i bezkształtowe |
| Piec | wsad + paliwo + wynik, pasek postępu, blok świeci gdy pali |
| Narzędzia | kilofy i miecze w trzech poziomach (drewno, kamień, żelazo) |
| Potwory | zombie, szkielet, pająk, creeper — AI, animacje, dropy |
| Walka | atak na potwory tym samym przyciskiem co kopanie, życie w sercach, odrzut, nietykalność, śmierć i respawn |

### Crafting

Przepisy odwzorowują oryginał, łącznie z przesuwaniem wzoru po siatce — kilof
zrobiony w prawym dolnym rogu 3×3 też zadziała.

| Wynik | Przepis | Gdzie |
|---|---|---|
| 4 deski | kłoda (dowolne pole) | ekwipunek |
| 4 patyki | deski nad deskami | ekwipunek |
| Stół rzemieślniczy | 2×2 desek | ekwipunek |
| Piec | 8 bruku w pierścieniu 3×3 | stół |
| Kilof | 3 materiały w rzędzie + 2 patyki pionowo | stół |
| Miecz | 2 materiały pionowo + patyk | stół |
| 4 strzały | sztabka + patyk + nić | stół |

W grze jest **księga przepisów** (klawisz `B` albo ikona książki): pokazuje
układ każdego przepisu na siatce, wynik z liczbą sztuk, wytopy w piecu oraz
podświetla na zielono to, na co masz właśnie składniki. Da się ją otworzyć
także z ekwipunku i ze stołu — ułożona siatka nie znika.

Cegły nie mają przepisu; powstają z wytopienia piasku w piecu.

Ruda żelaza wymaga kamiennego kilofa, a surowe żelazo trzeba wytopić w piecu
(paliwo: węgiel). Zbyt słabe narzędzie niszczy blok bez dropu — jak w oryginale.

### Dzielenie stosów

Jak w oryginale: **pustą ręką** prawy przycisk (albo przytrzymanie palcem na
telefonie) bierze **połowę stosu** — przy nieparzystej liczbie nadwyżka idzie
na kursor. **Z przedmiotem w ręce** ten sam gest kładzie **po jednej sztuce**,
więc osiem desek rozsypiesz na dowolnie małe porcje. Lewy przycisk działa
po staremu: podnosi cały stos, odkłada go albo scala z tym, co już leży.

### Potwory

| Gatunek | Zachowanie | Drop |
|---|---|---|
| Zombie | wolno prze na gracza, bije w zwarciu | czasem sztabka żelaza |
| Szkielet | trzyma dystans, strzela z łuku, nie strzela przez ścianę | kości, strzały |
| Pająk | szybki, wysoko skacze, osiem animowanych odnóży | nić |
| Creeper | podchodzi, zapala lont, wybucha i niszczy teren | proch |

Potwory pojawiają się 12–26 bloków od gracza, maksymalnie 6 naraz. Przeszkodę
na drodze pokonują skokiem. Lont creepera gaśnie, gdy uciekniesz.

**Atakowanie.** Wyceluj w potwora — celownik zmienia się w czerwony krzyżyk,
a nad nim pojawia się pasek życia z nazwą gatunku. Wtedy trzymaj ten sam
przycisk co przy kopaniu (`KOP/BIJ` albo lewy przycisk myszy); ciosy idą co
0,42 s. Obrażenia zależą od tego, co trzymasz: ręka 1, kilofy 2–4,
miecze 5–8. Promień celowania sięga 5,5 bloku i zatrzymuje się na ścianie,
więc nie da się uderzyć potwora zza bloku. Po zabiciu HUD pokazuje, co wypadło.

## Sterowanie

| Wejście | Akcja |
|---|---|
| `W` `S` `A` `D` / joystick | chodzenie |
| przeciągnięcie myszą lub palcem | rozglądanie |
| przytrzymanie / przycisk `KOP` | kopanie i atak na potwory |
| prawy przycisk myszy / `R` / `UŻYJ` | stawianie bloku, otwieranie stołu i pieca |
| `1`–`9`, kliknięcie slotu, scroll | wybór przedmiotu |
| `E` / ikona plecaka | ekwipunek i crafting |
| `B` / ikona książki | księga przepisów |
| prawy przycisk / przytrzymanie slotu | podział stosu na pół, potem po jednej sztuce |
| `Esc` | zamknięcie ekranu |
| `Spacja` / `SKOK` | skok (w locie: w górę) |
| `Shift` | sprint (w locie: w dół) |
| `F` / `LOT` | tryb latania |
| strzałki | rozglądanie klawiaturą |

Ikona pada w prawym górnym rogu włącza sterowanie dotykowe również na desktopie,
ikona `?` pokazuje ściągawkę.

## Układ kodu

```
lib/
  main.dart                     ekran gry, obsługa wskaźnika i focusu klawiatury
  src/core/block.dart           typy bloków: tekstury, twardość, wymagane narzędzie
  src/core/item.dart            przedmioty (bloki, surowce, narzędzia) i dropy
  src/core/inventory.dart       ekwipunek, stosy, przekładanie przez kursor
  src/core/recipes.dart         przepisy i dopasowanie wzoru do siatki
  src/core/furnace.dart         stan i logika wytopu w piecu
  src/core/tiles.dart           kafelki atlasu i poziomy cieniowania ścian
  src/render/atlas.dart         proceduralny atlas tekstur (piksel po pikselu)
  src/render/mesh_builder.dart  quady → Surface, z podziałem na limicie uint16
  src/render/chunk_renderer.dart siatki chunków + kolejka przebudowy
  src/render/overlay_meshes.dart ramka celu i modele przedmiotów w ręce
  src/render/mob_renderer.dart  modele potworów z klocków i animacja kończyn
  src/world/voxel_world.dart    tablica wokseli, zapis bloków, raycast
  src/world/voxel_body.dart     wspólna fizyka AABB gracza i potworów
  src/world/terrain.dart        generator terenu i drzew
  src/game/flutcraft_game.dart  pętla gry, kamera, kopanie, stawianie, wejście
  src/game/player.dart          sterowanie, kamera i zdrowie gracza
  src/game/mob.dart             gatunki potworów, AI, strzały, spawner
  src/game/held_item.dart       przedmiot trzymany przed kamerą + zamach
  src/game/hud_state.dart       migawka stanu dla warstwy UI
  src/ui/                       HUD, ekwipunek, piec, księga przepisów, sterowanie
```

## Znane ograniczenia prototypu

- Brak przezroczystości — nie ma wody ani szkła (wymagałoby sortowania i
  osobnego przebiegu z alpha blendingiem).
- Narzędzia się nie zużywają i nie ma cyklu dnia — potwory chodzą non stop.
- Zbite bloki i dropy z potworów lecą prosto do ekwipunku; nie ma
  przedmiotów leżących na ziemi.
- Potwory nie omijają przeszkód — pokonują je skokiem albo utykają.
- Świat jest skończony i trzymany w całości w pamięci; nie ma streamingu chunków.
- Siatki chunków budują się na wątku UI (2 chunki na klatkę), bez izolatów.
- Stan gry nie jest zapisywany między uruchomieniami.

## Impeller

`flutter_gpu` (a przez to `flame_3d`) działa tylko na Impellerze. Na iOS i
Androidzie jest domyślny; na macOS w Flutterze 3.44 trzeba go włączyć — w tym
repo robi to klucz `FLTEnableImpeller` w `macos/Runner/Info.plist`.
