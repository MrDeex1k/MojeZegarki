# Audyt Moje Zegarki — 2 października 2026

Kod bazowy: `af879b1`; aplikacja 0.8.2 (3). Build Debug z Xcode 27.0 (27A266a), Apple Swift 6.4. Testowane przez agent-device z `deviceHub: true`: iPhone 18 Pro / iOS 27.0 oraz iPhone 12 / iOS 17.5. Po wstępnym obejrzeniu zainstalowanych aplikacji zbudowano i zainstalowano bieżący kod, a dalsze testy wykonano na izolowanej bazie `--uitesting --reset-test-store --test-document-fixture`.

Najważniejszy wynik: potwierdzone zawieszenie wejścia do podglądu dokumentu na iOS 17.5 (BUG-01, także ręcznie), cztery obserwacje UX oraz miejsca do optymalizacji. Szczegóły i ograniczenia testów poniżej.

## Obserwacje UI

### UX-01 — istniejący dzień wygląda jak niezapisany (średni)

Na iPhonie 12: Harmonogram → Dodaj dni noszenia → TestBrand Document watch → 2 października → Zapisz. Powtórne otwarcie formularza i wybór tego zegarka pokazują „Wybrane dni: 0”, a zapisany dzień nie jest oznaczony. Można zaznaczyć go ponownie. Licznik opisuje zaznaczenie, nie liczbę nowych wpisów. Wyjaśnienie o pomijaniu duplikatów znajduje się dopiero pod kalendarzem.

Dowód: `screenshots/12-existing-day-unmarked.png`; nagranie `duplicate-day.mp4`. Oczekiwane: widoczne zapisane dni, osobny stan nowych wyborów i przycisk pokazujący liczbę rzeczywiście dodawanych dni.

Potwierdzenie końcowe UX-01: zapis samego duplikatu zamknął formularz, a podsumowanie nadal pokazywało „1 dzień noszenia”, bez informacji o zerowej liczbie nowych wpisów. Dalsze dowody: `screenshots/12-duplicate-selected.png`, `screenshots/12-duplicate-result.png`.

### UX-02 — wynik wybranego dnia wymaga samodzielnego przewinięcia (niski)

Na obu modelach, po zapisaniu noszenia, dotknięcie dnia w Harmonogramie dodaje wiersz zegarka pod całym kalendarzem. Przy górnej pozycji listy wynik pozostaje poniżej widocznego obszaru, bez przewinięcia do niego. Na iPhonie 12 przewinięcie o ok. 440 punktów odsłoniło wpis. Propozycja: przewinięcie do nagłówka wybranego dnia (z uwzględnieniem Reduce Motion) albo podgląd dnia w sheet. Dowód: `screenshots/18-day-result-below-fold.png` oraz snapshoty sesji.

### UX-03 — szybkie przeniesienie życzenia bez informacji zwrotnej/cofnięcia (średni)

Na iPhonie 12 utworzono życzenie Audyt / Marzenie i naciśnięto „Dodaj do kolekcji” bezpośrednio w wierszu. Wpis od razu zniknął; pojawił się pusty stan „Twój kolejny zegarek”. Brak potwierdzenia przeniesienia, akcji „Pokaż w kolekcji” i „Cofnij”. Nie oznacza to utraty zegarka — został przeniesiony do kolekcji. Ta sama etykieta w menu prowadzi natomiast do formularza, więc dwa wejścia mają różne skutki. Propozycja: zachować szybkie przeniesienie, ale dodać komunikat z nawigacją/cofnięciem, a wariant menu nazwać „Uzupełnij i dodaj…”. Dowody: `screenshots/12-wish-before.png`, `screenshots/12-wish-moved.png`, `wishlist-move.mp4`.

### UX-04 — ucięta nazwa filtra przy największym tekście (średni)

iPhone 18 Pro, Dynamic Type `accessibility-extra-extra-extra-large`: filtr „Wszystkie zegarki” pokazuje „Wszy…garki”, a duże kapsuły zajmują prawie całą wysokość ekranu. Propozycja: dla rozmiarów dostępności pionowy układ etykieta/wartość, wielowierszowa nazwa i zaokrąglony prostokąt zamiast kapsuły. Dowód: `screenshots/18-large-text.png`. Ucięcie systemowego tytułu nawigacji nie jest tu traktowane jako osobny błąd aplikacji.

### BUG-01 — zawieszenie wejścia do podglądu PDF na iOS 17.5 (wysoki, P1)

Istniejący test `FreeModuleUITests.testDocumentPreviewEditCancelSaveAndDelete`, iPhone 12 / iOS 17.5, build 0.8.2 (3) z bieżącego commitu:

1. Start z `--uitesting --reset-test-store --test-document-fixture -AppleLanguages (en) -AppleLocale en_US`.
2. Kolekcja → Document watch → Documents → Test invoice.
3. Oczekiwane: podgląd jednostronicowego PDF i dostępny przycisk `document.actions`.
4. Rzeczywiste: ekran pozostał na liście Documents, pętla UI nie zgłosiła bezczynności przez ponad 60 sekund; przycisk podglądu nie pojawił się, a test ponawiał odczyty przez ponad 170 sekund.

Proces aplikacji zużywał 100% CPU. Trzysekundowy profil `sample` wykazał footprint 3,3 GB i główny wątek pracujący w układzie SwiftUI / AttributeGraph, w tym `DocumentPreviewView.body`. To jest dowód zawieszenia procesu aplikacji, nie tylko wolnego testu. Nie ustalono jeszcze konkretnej przyczyny ani poprawki; nie należy automatycznie przypisywać winy parserowi PDFKit. Ten sam test na iOS 27.0 przeszedł w około 26 s.

Dowody: `screenshots/12-pdf-test-stall.png`, `pdf-hang-sample.txt`, `iphone12-test-log.txt`. Zawieszony przebieg i proces zatrzymano po zebraniu dowodów; pozostałe testy uruchomiono osobno. Priorytet: odizolować cykl layoutu/nawigacji przy `DocumentPreviewView` oraz sprawdzić ponownie iOS 17.5 i fizyczny telefon. Nie podnosić minimum iOS tylko po to, by ukryć regresję.

## Przegląd kodu i optymalizacje

Poniższe wnioski wynikają z analizy kodu. Poza BUG-01 nie wykonano profilu wydajności dużej kolekcji, więc nie deklaruję zmierzonego przyspieszenia. Priorytet P1 oznacza najbliższą poprawkę, P2 — kolejny etap, P3 — usprawnienie utrzymania.

| Priorytet | Miejsce | Wniosek i zalecenie |
| --- | --- | --- |
| P1 | `Features/Documents/DocumentPreviewView.swift:16`, `Features/Documents/DocumentsView.swift:47` | Zawieszenie przy otwieraniu dokumentu na iOS 17.5. Zredukować reprodukcję do nawigacji + stabilnego stanu podglądu, sprawdzić pętlę layoutu SwiftUI. Najpierw poprawność, potem wydajność. |
| P2 | `App/MojeZegarkiApp.swift:59–68` | Utworzenie bazy i usuwanie osieroconych plików są w jednym `do/catch`; błąd sprzątania powoduje ekran „Could not open collection”, mimo że baza mogła otworzyć się poprawnie. Oddzielić krytyczne otwieranie danych od sprzątania. Sprzątanie uruchamiać bez blokowania dostępu, z logiem i ponowieniem, ale skoordynować z aktywnymi importami, aby nie usunąć plików roboczych edytora. |
| P2 | `Features/Collection/TimepieceDetailView.swift:7–22`, `Features/Wear/WearView.swift:98–120` | Szczegóły jednego zegarka pobierają wszystkie WearLog i filtrują w pamięci. Dodać predykat po ID zegarka, tak jak już robi `DocumentsView`. W Harmonogramie ograniczać dane do potrzebnego filtra/zakresu i osobno liczyć podsumowania. |
| P2 | `Features/Wear/WearView.swift:109–120,179–182,343–368,486–492` | Przy przebudowach powstają kolejne filtry, grupowania, zbiory i parsowania dat. Wydzielić model podsumowania z jednym przebiegiem danych. Mierzyć 1 tys./10 tys./50 tys. wpisów i 100 zegarków w Instruments; nie dokładać cache bez kontroli invalidacji. |
| P2 | `Features/Wear/WearView.swift:10–15,34–36` | Każdy widoczny przycisk „dzisiaj” ma osobny TimelineView i Query. Przy większej kolekcji rozważyć jeden zbiór ID zegarków noszonych dziś, współdzielony przez listę, oraz jedno odświeżanie po zmianie dnia/powrocie z tła. Zachować reaktywność i test granicy północy. |
| P2 | `Features/Collection/PhotoView.swift:27–30`, `Features/Documents/DocumentPreviewView.swift:21` | Odczyt zdjęcia jest poza MainActor, lecz UIImage tworzony jest w widoku; w podglądzie dokumentu bezpośrednio w `body`. Wydzielić ładowanie/preparację obrazu i trzymać gotowy stan, dodać ograniczony pamięciowo cache miniatur, unikać powtarzania pracy przy zmianie menu/notatek. To możliwość optymalizacji, nie zmierzony bottleneck. |
| P2 | `Features/Collection/TimepieceEditorView.swift:147–158`, `Features/Documents/DocumentsView.swift:106–114` | Zdjęcia z PhotosPicker wczytywane są w całości jako Data. Limit dokumentu 20 MB działa dopiero po wczytaniu; import z Files ma już poprawny bounded read. Dodać ścieżkę importu plikowego/Transferable i kontrolę rozmiaru przed pełnym odczytem; limit liczby zdjęć na partię i postęp/cancel dla długich importów. |
| P2 | `Features/Documents/DocumentPreviewView.swift:18–26` | Gdy plik istnieje, ale UIImage nie daje się utworzyć, gałąź z `data` może pozostawić pusty podgląd bez błędu. Wprowadzić jawne `loading / loaded / failed` oraz walidację dekodowania, tak samo dla niepoprawnego PDF. To wniosek statyczny, bez reprodukcji uszkodzonego pliku w tym audycie. |
| P2 | `Features/Wear/WearView.swift:320–326`, `Persistence/CollectionStore.swift:128–145` | Operacja grupowa zwraca liczbę nowych wpisów, ale UI ją ignoruje. Wykorzystać wynik w potwierdzeniu i odróżnić 0 dodanych od udanego dodania. Nie zmieniać poprawnej idempotencji warstwy danych. |
| P3 | `Features/Wear/WearView.swift` | Plik łączy szybkie oznaczanie, listę, edytor, kalendarz i statystyki (ponad 600 linii). Podzielić według tych odpowiedzialności; wspólną semantykę dnia i kalendarza umieścić w domenie. Nie ma potrzeby pełnego przepisywania architektury. |

Mocne strony warte zachowania: Gregorian `WearDay` niezależny od późniejszych zmian strefy; transakcyjny zapis i rollback; walidacja całego zestawu dni przed zapisem; brak duplikatów; wersjonowany schemat i test migracji; aktory do operacji plikowych; miniatury zdjęć; staging plików; jawnie wyłączony CloudKit; izolowana baza UI testów. Cena zapisana jako kanoniczny decimal string unika problemów `Double`.

Dodatkowe usprawnienia produktu:

- Zmienić polskie „Harmonogram” na „Noszenie” lub „Historia”: ekran zapisuje przeszłość, a nie planuje przyszłość. To rekomendacja terminologii, nie błąd techniczny.
- W kalendarzu historii dodać skok do miesiąca/roku i powrót do dzisiaj. Obecnie dotarcie do dnia sprzed pięciu lat wymaga około 60 tapnięć w poprzedni miesiąc. Formularz MultiDatePicker ma już wybór miesiąca/roku; historia powinna oferować podobną wygodę.
- Widok pojedynczego zegarka nie potrzebuje legendy „1 / 2 / 3+ zegarki”; wystarczy „Noszony / Nienoszony”.
- Przy zmienionym formularzu rozważyć ochronę przed przypadkowym zamknięciem gestem i odrzuceniem zmian. Aktualna `interactiveDismissDisabled` chroni tylko import/zapis, nie sam zmodyfikowany draft.
- Powiększyć efektywne pola dotyku małych ikon w wierszach bez powiększania rysunku. W obserwacji startowej ikona szybkiego noszenia miała ramkę AX 28×28 pt; rzeczywisty hit area wymaga osobnego pomiaru, więc nie traktuję tego jako potwierdzonego błędu dotyku.
- W Ustawieniach pokazać `0.8.2 (3)` zamiast samego `0.8.2`, aby feedback testerów identyfikował konkretny build.

## Propozycja dni noszenia

Rekomendowany wariant: **dodawanie nowych dni z widoczną historią**, z oddzielnym usuwaniem. Zachowuje obecne reguły i ogranicza przypadkowe kasowanie historii.

| Stan | Wygląd | Zachowanie |
| --- | --- | --- |
| Już zapisany | Delikatne wypełnienie i ✓, etykieta dostępności „zapisano” | Tap pokazuje „Ten dzień jest już zapisany”; nie tworzy nowego wyboru. Usunięcie dostępne w historii dnia. |
| Nowy, zaznaczony | Mocne wypełnienie i + | Tap ponownie odznacza. |
| Niezapisany | Zwykły numer | Tap zaznacza do dodania. |
| Dzisiaj | Osobne subtelne oznaczenie aktualnego dnia | Może być jednocześnie zapisany/zaznaczony. |
| Przyszły | Wygaszony, niedostępny | Brak zapisu. Dla archiwalnego zegarka także dzisiaj niedostępne. |

Stopka: „Nowe dni: 2”, przycisk „Dodaj 2 dni”, po zapisie „Dodano 2 dni noszenia”. Bez nowych dni przycisk nieaktywny. Przy pojedynczym zegarku otwierać formularz od razu w jego kontekście; przy zmianie zegarka przeliczać istniejące dni i czyścić nowe zaznaczenia, żeby nie przenieść ich przypadkowo.

Model stanu: `existingDayKeys: Set<WearDay>`, `pendingDayKeys: Set<WearDay>`, `displayedMonth`. W UI wyświetlać oba zbiory odmiennie; do `logWear` wysyłać tylko różnicę. Ponowna weryfikacja przy zapisie pozostaje w Store. Istniejący kalendarz historii może współdzielić siatkę i obliczanie dat z nowym selektorem, ale akcje muszą pozostać jawnie rozdzielone. Całość może działać na iOS 17 bez nowej zależności.

Samo wstępne zaznaczenie wszystkich zapisanych dni w MultiDatePicker jest kuszące, ale niewystarczające: odznaczenie sugerowałoby usunięcie, podczas gdy obecny zapis tylko dodaje. [MultiDatePicker](https://developer.apple.com/documentation/swiftui/multidatepicker) wiąże jeden zbiór wyboru; do wyraźnego rozróżnienia historii od nowych zmian rekomenduję własną siatkę na bazie istniejącego `WearHistoryCalendar`.

Alternatywa późniejsza: pełny edytor historii, w którym zapisane dni są zaznaczone, a odznaczenie planuje usunięcie. Wymaga wtedy podsumowania „Dodasz 2, usuniesz 1”, osobnego ostrzeżenia o usuwaniu i atomowej operacji add/remove. Nie mieszać tego z formularzem nazwanym „Dodaj dni”.

Kryteria akceptacji:

1. Istniejące dni są widoczne od otwarcia, bez otwierania drugiego widoku.
2. Wybór samego duplikatu nie aktywuje zapisu; wybór mieszanego zestawu liczy tylko nowe dni.
3. Zmiana zegarka, miesiąca, locale, strefy i przekroczenie północy nie zmienia znaczenia zapisanego dnia.
4. Archiwalny zegarek przyjmuje tylko przeszłe dni; wiele zegarków jednego dnia nadal dozwolone.
5. Błąd zapisu zachowuje wybór do ponowienia; anulowanie niczego nie zapisuje.
6. VoiceOver odczytuje pełną datę i stan. Duży tekst ma układ/listę alternatywną, jeżeli siedem kolumn przestaje być czytelne. Stan nie zależy wyłącznie od koloru.

## Narzędzia, pakiety i wersje

Sprawdzono stan lokalny i oficjalne informacje 2.10.2026.

| Element | Stan | Rekomendacja |
| --- | --- | --- |
| Zależności zewnętrzne | Brak SPM/CocoaPods/npm w projekcie aplikacji | Nie ma pakietów wymagających aktualizacji. SwiftUI, SwiftData, Charts, PDFKit i CryptoKit pochodzą z SDK systemowego. |
| Xcode | 27.0, build 27A266a | Zgodny ze stabilnym wydaniem Apple z 14.09.2026. Dostępne nowsze bety, m.in. 27.2 beta 2; brak powodu do migracji produkcyjnej wyłącznie dla numeru. [Apple Releases](https://developer.apple.com/news/releases/) |
| Swift | Kompilator 6.4; `SWIFT_VERSION = 6.0`; strict concurrency `complete` | Poprawna konfiguracja. `SWIFT_VERSION` opisuje tryb języka Swift 6, nie wersję kompilatora — nie zmieniać na 6.4. [Swift 6.4](https://www.swift.org/blog/swift-6.4-released/), [zgodność Xcode](https://developer.apple.com/xcode/system-requirements/) |
| Minimum systemu | iOS 17.0 | Zachować, jeśli nadal produktowo wymagane; najpierw naprawić potwierdzone zawieszenie na 17.5. Test z 17.5 nie potwierdza 17.0. |
| Runtime testowy | iOS 17.5 + 27.0 | Dodać bieżący stabilny iOS, gdy runtime będzie dostępny. Apple opublikowało iOS 27.0.1; dostępność OS nie oznacza automatycznie dostępnego runtime w Xcode. [Apple Releases](https://developer.apple.com/news/releases/) |
| Formatowanie | `xcrun swift-format` dostępny, brak konfiguracji w repo | Dodać `.swift-format` i lint w CI; formatowanie zrobić osobnym commitem. Narzędzie jest dołączone do Swift od 6 / Xcode 16. [swift-format](https://github.com/swiftlang/swift-format) |
| CI / test plan | Brak workflow i `.xctestplan` w repo | Dodać powtarzalny build + unit + UI dla starego/nowego iOS, macierz PL/EN i testy dużego tekstu. Zapisywać xcresult oraz screenshoty przy błędzie. Ustawić timeout testów, aby zapętlenie nie trzymało runnera. |
| Framework testów | XCTest, 18 testów logiki + 5 UI | Zachować działające testy. Nowe testy domeny można pisać w Swift Testing; UI nadal XCTest. Nie ma potrzeby masowej migracji. [Apple Testing](https://developer.apple.com/documentation/xcode/testing) |
| Dokumentacja | README i instrukcje testowe opisują starsze środowisko/release | Uaktualnić wersje, zakres już istniejącego kalendarza/statystyk i faktycznie zweryfikowane systemy. |

Build nie zgłosił błędów kompilacji Swift. Pojawiło się jedynie ostrzeżenie narzędzia ekstrakcji metadanych, że projekt nie zależy od AppIntents; nie uzasadnia to dodawania frameworka. Kontrola katalogu tłumaczeń znalazła 201 wpisów; bez jawnego PL pozostały dwa formaty liczb/daty oraz `Days` użyte jako nazwa miary wykresu. To nie jest pełny audyt lokalizacji; nie znaleziono w tej kontroli brakujących tłumaczeń kluczowych formularzy.

## Końcowa weryfikacja

BUG-01 odtworzono również **ręcznie przez DeviceHub**, po świeżym uruchomieniu izolowanej bazy z tym samym fixture, bez aktywnego testu XCTest: Document watch → Documents → Test invoice. Tap zakończył się bez ustabilizowania UI, ekran pozostał na liście dokumentów i proces znów zużywał 100% CPU. Dowody: `pdf-open-iphone12.mp4`, `screenshots/12-pdf-manual-stall.png`. Proces zatrzymano po zebraniu dowodów.

| Weryfikacja | iPhone 18 Pro / iOS 27.0 | iPhone 12 / iOS 17.5 |
| --- | --- | --- |
| Build bieżącego kodu | PASS | Ten sam build, PASS uruchomienia |
| Testy logiki, plików, migracji, blokady | 18/18 PASS | 18/18 PASS |
| UI: create/edit/persist/archive/restore/delete | PASS | PASS |
| UI: polskie tłumaczenie i anulowanie | PASS | PASS |
| UI: blokada zasłania kolekcję przy starcie | PASS | PASS (oddzielny przebieg) |
| UI: dokument preview/edit/cancel/save/delete | PASS | Zawieszenie aplikacji, przebieg przerwany |
| UI: wishlist → collection → wear → restart → stats | PASS | FAIL przy oczekiwaniu na zniknięcie `editor.brand` po Cancel (linia 31); dalsza część testu nie wykonana |
| Ręcznie: anulowanie przeniesienia wishlist | — | PASS w osobnym powtórzeniu; `wishlist-cancel.mp4`, `screenshots/12-cancel-manual-pass.png` |
| Ręcznie: dodanie noszenia i kalendarz historii | PASS | PASS |
| Ręcznie: ponowny zapis tego samego dnia | Analiza wspólnego kodu | Potwierdzone UX-01, bez duplikatu |
| Ręcznie: największy Dynamic Type | Ucięty filtr, UX-04 | Nie sprawdzano |

Łącznie: **23/23 PASS na iOS 27.0**. Na iOS 17.5 **21 testów PASS**, jeden scenariusz zawiesza aplikację, jeden zakończył się błędem automatyzacji, którego ręczne powtórzenie nie potwierdziło jako stałego błędu aplikacji. Ten drugi pozostaje nierozstrzygnięty; możliwy problem synchronizacji tapnięcia/animacji lub drzewa AX wymaga osobnej stabilizacji. Nie raportuję zielonej całej suity na iOS 17.

Pełny xcresult iPhone 18: `.build/audit-18.xcresult`. Logi skopiowano do tego katalogu (`iphone18-test-log.txt`, `iphone12-test-log.txt`, `iphone12-remaining-test-log.txt`). Przebieg iPhone 12 oraz finalizacja drugiego przebiegu wymagały przerwania; kompletności ich xcresult nie potwierdzono. Czasy komend agent-device nie są miarą szybkości aplikacji.

Nie sprawdzono: fizycznego Face ID/kodu, realnego zużycia baterii, dostawców iCloud Drive, importu z fizycznego aparatu, pełnego VoiceOver, presji małej ilości dysku, dużej kolekcji ani pełnej macierzy język/kontrast/rozmiar tekstu. Symulatory nie zastępują tych testów. Oznaczenia AX „covered” na sheetach iOS 27 nie były uznawane za błąd UI bez dowodu wizualnego; w potrzebnych miejscach użyto tapnięć według aktualnego screenshotu.

## Zalecana kolejność prac

1. Naprawić zawieszenie podglądu dokumentu na iOS 17.5 i zapewnić stabilne przejście testu na obu systemach.
2. Wdrożyć selektor dni z widoczną historią oraz licznikiem nowych wpisów; dodać testy samego duplikatu, mieszanej selekcji, archiwum i zmiany zegarka.
3. Poprawić filtr/wiersze dla Dynamic Type i widoczność wyniku wybranego dnia.
4. Oddzielić błąd otwierania bazy od błędu sprzątania plików; ograniczyć zapytania do potrzebnych wpisów.
5. Dodać powtarzalne CI/test plan, lint formattera, pomiary dużej kolekcji i czytelne informacje o buildzie.

Audyt nie zmienia kodu produkcyjnego ani wersji narzędzi. Dostarcza raport, screenshoty, nagrania i interaktywną propozycję selektora dni w rozmowie.

Stan po audycie: przywrócono rozmiar tekstu iPhone 18 Pro (`extra-large`); sesje agent-device zamknięto. Na obu symulatorach zainstalowany jest bieżący build Debug. W zwykłej bazie iPhone 12 pozostał utworzony podczas wstępnego testu zegarek „Audyt / Test 2026” (bez zdjęć i wpisów noszenia). Automatyczna kontrola uprawnień odrzuciła jego sprzątnięcie, ponieważ traktuje trwałe usunięcie jako wymagające wyraźnej zgody; nie obchodzono tej blokady. Dalsze testy korzystały z oddzielnej bazy UI testów.

Aktualizacja 3.10.2026: po wyraźnej zgodzie użytkownika usunięto wpis „Audyt / Test 2026” przez interfejs aplikacji na symulatorze iPhone 12. Potwierdzono powrót do pustej kolekcji; sesję zamknięto. Poprzednia blokada sprzątania jest rozwiązana.

Aktualizacja implementacyjna 3.10.2026: użytkownik zaakceptował wdrożenie wszystkich etapów. Opis zmian i końcowa weryfikacja znajdują się w [raporcie implementacji](../implementacja-2026-10-03/README.md). Powyższe wyniki pozostają zapisem stanu sprzed poprawek.
