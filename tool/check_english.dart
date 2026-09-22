// Verifies that the source reads in English — comments included.
//
// The tutorial is recorded in English, so a Polish comment in the code is a
// comment the viewer cannot read. The Polish that *should* exist lives in the
// translation files, and those are the only place this check allows it.
//
// Run from the repository root: `dart run tool/check_english.dart`.
import 'dart:io';

/// Characters that only appear in Polish, never in English.
final _polish = RegExp(
  '[\u0105\u0107\u0119\u0142\u0144\u00f3\u015b\u017a\u017c'
  '\u0104\u0106\u0118\u0141\u0143\u00d3\u015a\u0179\u017b]',
);

/// Polish words that carry no diacritics, so the letters alone would not
/// give them away.
///
/// Built from the words this project actually uses: every Polish token in
/// the translation history minus every word that appears on the English
/// side. A hand-picked handful used to sit here, and it let twelve Polish
/// comments through, because the words that slip past a list like that
/// are never the ones anybody would have thought to write down.
final _polishWords = RegExp(
  r'\b(akcja|aktualnego|aktualnie|albo|alfa|amplitudzie|ataku|atlasu|bardziej|' // polish-ok
  r'barku|bazowy|bezczynnie|bezpiecznie|bicie|bierzemy|bije|biodra|' // polish-ok
  r'bitowe|bity|bliski|blokach|blokowi|boczna|boku|bruk|bruku|bucha|' // polish-ok
  r'budowane|buduje|buja|bywa|celowanego|celowniku|celowo|charakterystyczna|' // polish-ok
  r'chodzenie|chodzi|chroni|chunki|chunku|chwilowa|ciemna|ciemniejsze|' // polish-ok
  r'cienkiej|ciosu|cofa|cokolwiek|cooldownu|craftingu|creepery|cykl|' // polish-ok
  r'cykle|czapki|czarna|czas|czasu|czeka|czemu|czerwono|czerwony|czterech|' // polish-ok
  r'cztery|czytamy|czytelnie|dalej|danego|danym|darni|deklaracje|dekoduje|' // polish-ok
  r'desek|destrukcja|deterministyczne|deterministyczny|dobiera|dodanie|' // polish-ok
  r'dodano|dolna|dolnym|domenie|domenowe|dopasowane|dopasowanie|dopiero|' // polish-ok
  r'dostaje|dotknij|dotyka|dotykowe|dotykowego|dowolnego|dowolnych|' // polish-ok
  r'dowolnym|drewniany|drewno|dropu|drugiej|drugim|drzewa|drzewo|dysku|' // polish-ok
  r'dzielimy|edycji|egzemplarze|ekran|ekranie|ekranu|ekrany|fabryki|' // polish-ok
  r'faktycznie|fazowanej|fazy|fizyczna|fizyka|fuga|gatunek|gatunki|' // polish-ok
  r'gatunku|gdyby|gdzie|generowanie|generowany|generuje|gotowa|graczowi|' // polish-ok
  r'grafika|granicach|granicy|gruncie|grzebie|gubi|ignoruje|ikona|ikonach|' // polish-ok
  r'ikonki|implementacja|inaczej|indeksem|indeksowane|indeksy|inna|' // polish-ok
  r'innej|inny|interakcja|jaki|jakie|jakikolwiek|jakim|jako|jasna|jeden|' // polish-ok
  r'jedna|jednego|jedno|jednostkach|jednostkowego|jednym|jedzenia|jego|' // polish-ok
  r'kadrze|kafelek|kafelka|kamery|kamiennego|kasuje|kilka|kilkaset|' // polish-ok
  r'klasie|klatce|klatek|klatkach|klatki|klawiatura|klawisz|klawisza|' // polish-ok
  r'klikania|kliknij|klucz|kluczowane|kodowane|kolejce|kolejka|kolekcje|' // polish-ok
  r'kolizje|kolor|koloru|kolory|kolorze|kolumn|kolumna|kolumnie|kolumny|' // polish-ok
  r'komendzie|kompilator|komponent|komponentu|komponenty|komunikat|' // polish-ok
  r'konkret|konstruktorze|kopania|kopanie|kopaniu|kopiowane|korona|' // polish-ok
  r'kosztu|kratek|kroku|kropka|kulka|kursor|kursora|kursorze|latania|' // polish-ok
  r'latanie|leci|leciutko|lekkie|lepszego|lewej|lewo|liczbie|liczby|' // polish-ok
  r'liczenia|licznika|limitem|listy|locie|logiczny|logiki|losowanie|' // polish-ok
  r'macha|macierzysta|malowana|mapy|martwy|masz|maszyna|meshe|miecz|' // polish-ok
  r'miecza|miejscach|miejscami|miejsce|miejscu|migawek|minecrafcie|' // polish-ok
  r'minimalny|mnogiej|mocniej|modele|modeli|modelu|mozaika|mruga|musi|' // polish-ok
  r'mutowalny|nadpisujemy|najpierw|napotkany|naraz|nazwa|nazwie|nich|' // polish-ok
  r'niczego|nieaktualny|nieco|niego|niej|nieodwracalny|niepusty|nieregularna|' // polish-ok
  r'niskim|niszczy|normalna|nowa|nowe|nowego|nowy|nowych|numer|numeracja|' // polish-ok
  r'obcina|obcy|obiekcie|obiekt|obracamy|obszarowe|oczu|oczywista|odcieni|' // polish-ok
  r'odcinku|odrodzono|odwzorowuje|ograniczony|okolica|oktaw|opada|operacji|' // polish-ok
  r'opisanej|opisem|opisuje|oprawa|oraz|oryginale|osiach|osie|osiem|' // polish-ok
  r'osobne|ostatni|ostatnie|ostatniego|otrzymaniu|otwarto|otwarty|otwiera|' // polish-ok
  r'otwieranie|oznaczania|palcem|paleniska|paleniskiem|palenisko|paliwa|' // polish-ok
  r'paliwo|pary|pasek|pasku|patrzenie|patyk|patyki|piasek|piaszczysta|' // polish-ok
  r'pierwszej|pierwszy|piksel|pikselach|pikseli|pionie|pionowe|pionowo|' // polish-ok
  r'pionowy|plecak|plecaka|podanych|podczas|podejdzie|podmiana|podmienia|' // polish-ok
  r'podmieniamy|podnosi|podnoszenia|podpis|podskocz|podstawia|podstawy|' // polish-ok
  r'pojawi|pojawienia|pojedynczego|pojedynczy|pokazania|pokazywana|' // polish-ok
  r'pokonano|polem|pomocnicze|poprzeczka|populacja|porcja|porcji|posiada|' // polish-ok
  r'posortowanej|postaw|postawieniu|postawione|postawisz|potrafi|potrzebne|' // polish-ok
  r'potrzebny|potrzebujesz|potrzeby|potworom|potworowi|powierzchnia|' // polish-ok
  r'powierzchnie|powietrze|powoli|powrotem|poziom|poziomej|poziomo|' // polish-ok
  r'poziomu|poziomy|pracy|prawo|prawym|prezentacji|proceduralnie|proch|' // polish-ok
  r'promienia|prosta|prostu|prototypie|przebudowie|przechodzi|przecina|' // polish-ok
  r'przeciwfazach|przed|przedmiocie|przedmiotu|przedmioty|przekazuje|' // polish-ok
  r'przekazywany|przekroczeniu|przemielenie|przepis|przepisuje|przepisy|' // polish-ok
  r'przerabia|przerwie|przerwy|przerywamy|przesuwa|przesuwaniem|przesuwany|' // polish-ok
  r'przewijania|przodu|przyciemnia|przyciemnienia|przyciemnienie|przyjmie|' // polish-ok
  r'przyklejamy|przyspiesza|przytrzymaj|pulsem|punkcie|pustce|puste|' // polish-ok
  r'pustego|radiany|ramka|razie|razu|reaguje|regeneracji|regeneruje|' // polish-ok
  r'renderowany|renderuje|reszta|rodzaj|rogach|rogi|rogu|rozbicia|rozbijania|' // polish-ok
  r'rozbijany|rozmiarze|rozpalonej|rozruch|rozsiew|rozsypuje|ruda|rudy|' // polish-ok
  r'rusza|rysowania|rysowany|rysuje|rysujemy|ryzach|rzadki|rzadkie|' // polish-ok
  r'samo|samym|scala|sekunda|sekundach|sekundy|serduszkach|setkach|' // polish-ok
  r'shaderze|siatce|siatek|siedzi|skalarne|skali|skok|slocie|slotu|' // polish-ok
  r'sobie|spacja|spawnu|specjalnych|spoczynku|spodziewamy|spokoju|sporadycznie|' // polish-ok
  r'sprawdzamy|sprawdzi|stanie|starcie|startowe|startowy|startowym|' // polish-ok
  r'startu|statystyki|stawiamy|stawianego|stawiania|stawianie|sterowania|' // polish-ok
  r'sterowanie|steruje|stole|stopni|stopy|stosie|stosy|strategia|streamingu|' // polish-ok
  r'strony|strop|stuknij|sumowanie|surowca|surowe|sygnalizujemy|symulacji|' // polish-ok
  r'synchronizuje|szansa|szerokim|szkieleta|sztabka|sztuce|szum|szumem|' // polish-ok
  r'szumu|szybkiego|szybko|tablicy|tego|teksela|tekstu|tekstura|tekstury|' // polish-ok
  r'telefon|telefonie|temu|teraz|terenu|testy|tickiem|tolerancja|traci|' // polish-ok
  r'trafienia|trafienie|trafieniu|trafionej|trafiony|trakcie|traktuje|' // polish-ok
  r'traktujemy|transformacje|trapez|tryb|trywialne|trzeba|trzech|trzonek|' // polish-ok
  r'trzonka|trzymamy|trzymana|trzymany|trzymanym|trzymasz|tych|tylnych|' // polish-ok
  r'tylu|ujemna|ujemne|ukrywa|upuszcza|ustawionym|usuwania|walka|walki|' // polish-ok
  r'warstw|warstwa|warstwie|warstwy|warte|wciskamy|wektory|wersji|widoczna|' // polish-ok
  r'widoczny|widok|widzenia|widzi|wirtualny|wokselach|wokseli|wolno|' // polish-ok
  r'wpisane|wraca|wracamy|wraz|wsad|wskazuje|wtedy|wybiera|wybierz|' // polish-ok
  r'wybuch|wybuchy|wyceluj|wydzielone|wygenerowanego|wygrywa|wyjmowania|' // polish-ok
  r'wyjmuje|wykonanie|wykonaniu|wykonuje|wykrywania|wymiarach|wymienialna|' // polish-ok
  r'wymusza|wynik|wynikowy|wyniku|wypada|wypalone|wystarczy|wystawia|' // polish-ok
  r'wystrzelona|wytapia|wyznacza|wzoru|wzorzec|zachowanie|zachowuje|' // polish-ok
  r'zaczepia|zaczepienia|zaczyna|zadaje|zadanej|zadany|zadawane|zajmuje|' // polish-ok
  r'zamach|zamachu|zamarza|zamiast|zamienia|zamyka|zanim|zaostrzone|' // polish-ok
  r'zapalonym|zapis|zapisu|zapisuje|zapomnienie|zaraz|zatrzymana|zawiera|' // polish-ok
  r'zawieszone|zaznaczenia|zbiciu|zdarzenia|zdarzenie|zdejmuje|zdobywa|' // polish-ok
  r'zdrowia|zdrowie|zeru|zestaw|zgodnie|zgrubienia|ziarno|zieleni|zielonej|' // polish-ok
  r'ziemia|zimny|zjada|zjechaniem|zmian|zmiana|zmianie|zmieni|zmienia|' // polish-ok
  r'zmieniaj|zmieniona|zmienione|znaczenia|znaczenie|znaczy|znajduje|' // polish-ok
  r'znak|znowu|zobaczy|zrobiony|zwarciu|zwykle)\b', // polish-ok
  caseSensitive: false,
);

/// A line ending in this marker is allowed to contain Polish: a test that
/// asserts a Polish translation has to write one out.
const _escapeHatch = 'polish-ok';

/// Paths whose whole job is to hold Polish.
const _allowed = [
  'packages/flutcraft_l10n/lib/l10n/app_pl.arb',
  'packages/flutcraft_l10n/lib/src/generated/app_localizations_pl.dart',
];

/// File types worth reading: code, translations, docs and CI config.
const _checkedExtensions = ['.dart', '.arb', '.md', '.yaml'];

void main() {
  final offenders = <String, int>{};

  for (final file in _filesToCheck()) {
    final hits = file
        .readAsLinesSync()
        .where((line) => !line.contains(_escapeHatch))
        .map(
          (line) =>
              _polish.allMatches(line).length +
              _polishWords.allMatches(line).length,
        )
        .fold(0, (sum, count) => sum + count);
    if (hits > 0) offenders[file.path] = hits;
  }

  if (offenders.isEmpty) {
    stdout.writeln('English OK — no stray Polish outside the translations.');
    return;
  }

  stderr.writeln('Polish text found outside the translation files:');
  for (final entry in offenders.entries) {
    stderr.writeln('  ${entry.key}  (${entry.value} hits)');
  }
  stderr.writeln('\nThe series is in English; translations belong in ARB.');
  exit(1);
}

/// Every file worth checking: the docs at the root, plus the packages, the
/// app, the tools and the CI config.
Iterable<File> _filesToCheck() {
  final roots = [
    Directory('packages'),
    Directory('app'),
    Directory('tool'),
    Directory('.github'),
  ].where((directory) => directory.existsSync());

  return [
    ...Directory('.').listSync().whereType<File>(),
    ...roots.expand((root) => root.listSync(recursive: true)).whereType<File>(),
  ].where(
    (file) =>
        _checkedExtensions.any(file.path.endsWith) &&
        !_allowed.any(file.path.endsWith) &&
        !file.path.contains('/build/') &&
        !file.path.contains('/.dart_tool/'),
  );
}
