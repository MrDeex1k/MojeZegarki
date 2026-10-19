# Wdrożenie zaleceń audytu

19 października 2026. Branch `audit/app-review`. Kod wdrożenia: `987082c`. Zakres pozostaje lokalny: bez konta, backendu i synchronizacji. Właściciel zatwierdził zachowanie systemowego backupu oraz pełną ochronę plików po zablokowaniu urządzenia z ustawionym kodem. iPhone Duo jest odłożony do osobnego etapu; docelowa regresja obejmuje iPhone 12 / iOS 17.5 i iPhone 18 Pro / iOS 27.0.

Raport [APP-AUDIT.md](APP-AUDIT.md) opisuje stan wyjściowy. Poniższa tabela odnosi jego ustalenia do zmian, bez utożsamiania kompilacji z walidacją na fizycznym telefonie.

## Realizacja

| ID | Wdrożenie i zakres potwierdzenia |
|---|---|
| A01 | Osobny `DocumentNotesView`: przewijanie, zaznaczanie całej treści, wejście bez edycji. Skrót pod dokumentem ma jawny odnośnik do pełnej notatki. Test UI z AX XXXL i długim tekstem. |
| A02 | Przycisk dodawania dni ma pełną nazwę oraz liczbę wybranych dni, także gdy pokazuje `+N`. |
| A03 | Automatyczne przewijanie historii i przełączanie porządkowania respektują Reduce Motion. |
| A04 | `reconcileAssets` wykonuje niezależne próby dla zdjęć i dokumentów, zbiera oba błędy. Każda próba sprzątania wymaga poprawnego odczytu referencji. Testy wymuszają awarie. |
| A05 | Walidacja i odczyt pozycji życzenia poprzedzają mutacje modeli. Test awarii fetch sprawdza istniejący model, brak niezapisanych zmian i brak częściowego insertu. |
| S01 | Wspólne `StorageProtection`, `.complete` dla istniejącej kolekcji i nowych załączników, entitlement `NSFileProtectionComplete` w Debug i Release. Klasa bazy i sidecarów jest ponawiana przed i po zapisie. Błąd metadanych po udanym zapisie jest logowany prywatnie, nie udaje rollbacku i nie powoduje porzucenia zapisanych załączników. Osłona UI działa także przy niedostępnych chronionych danych; inicjalizacja bazy i odczyt preferencji czekają na dostępność. Obsłużono ponowne odblokowanie i wyczyszczenie cache miniaturek. Egzekwowanie klasy ochrony wymaga fizycznego urządzenia. |
| S02 | Backup pozostaje włączony na poziomie plików kolekcji. Ustawienia PL/EN i README wyjaśniają lokalne przechowywanie, systemową kopię i dodatkową blokadę aplikacji. Test sprawdza flagę backupu i zachowanie plików istniejących. |
| S03 | Testy 1/100/1000 stron PDF, dokładnej granicy 20 MB, przekroczenia granicy i anulowania; istniejące testy sprawdzają uszkodzone dane oraz obraz 4200×2400 redukowany do 4000 px. Pozostaje profilowanie patologicznie złożonych PDF-ów i szczytowej pamięci na urządzeniu. |
| S04 | Dowolny szczegół błędu sprzątania jest logowany jako prywatny, z ogólną kategorią Storage. |
| O01 | Osobne widoki zakresu zapytania. Wybrany zegarek jest filtrowany w SwiftData, statystyki 30 dni/roku pobierają tylko odpowiedni przedział. Cały okres zachowuje pełny zbiór. Test porównuje wyniki ograniczonych zapytań z pełną historią na granicach dat i między zegarkami. |
| O02 | Leniwa galeria edytora i ranking statystyk; wydzielony `WatchStatisticsRow`. |
| O03 | Zmierzono import i przygotowanie pierwszej strony syntetycznych PDF-ów. Dla tego zestawu nie ma uzasadnienia do przenoszenia niesendowalnego `PDFDocument` między aktorami. Dekodowanie do wyświetlania nadal korzysta z `byPreparingForDisplay`. Nie zadeklarowano braku main-thread stalls dla dowolnego dokumentu. |
| O04 | Wyniki wyszukiwania i grupowania priorytetów są obliczane raz w renderowaniu, fraza jest przycinana raz na filtrowanie, zdjęcia szczegółów są sortowane raz. Bez cache wymagającego dodatkowej invalidacji. |
| R01 | Wspólne `CurrencyPicker`/`CurrencySelectionView`, `OptionalDateField`, potwierdzenie porzucenia i `.appError`. Waluty pokazują kod w formularzu i pełną nazwę na osobnym ekranie, co ogranicza ściskanie treści przy dużym tekście. |
| R02 | `DraftAssetSession` zarządza zadaniem importu, anulowaniem i utworzonymi plikami. Przejęcie pliku dokumentu następuje dopiero w `onAppear`, ponieważ tymczasowa wartość początkowa `@State` może być odrzucona przez SwiftUI. Podgląd lub wejście do podwidoku nie usuwa plików szkicu. Commit zachowuje referencjonowane zasoby, a porzucenie sprząta nowe. Testy obejmują spóźniony wynik po anulowaniu i zwolnienie sesji. Edytory blokują podwójny zapis. |
| R03 | Oddzielne edytory, podglądy UIKit, loader obrazów, zachowanie przewijania, filtr historii, wiersz wpisu i wspólny `WatchIdentityLabel`. Małe typy domenowe są w katalogach funkcjonalnych. Grupy Xcode odpowiadają plikom na dysku. |
| R04 | Operacje `CollectionStore` rozdzielono na Collection/Wishlist/Wear/Documents/Assets, mapowania i migracje mają własne katalogi. Deklaracje snapshotów V1/V2/V3 są identyczne z bazą sprzed reorganizacji. Jeden kontener i kontekst pozostają wspólną granicą zapisu. |
| Q01 | Automatyczny audyt EN semantyki, traitów, hit region, kontrastu i ucinania obejmuje kolekcję, edytory, historię, statystyki, ustawienia i podgląd dokumentu. Próba audytu blokady może być pominięta, gdy systemowe uwierzytelnienie przejmuje proces pierwszoplanowy. Wąskie wyjątki opisano niżej. |
| Q02 | Obraz dokumentu ma przyciski powiększania, pomniejszania i resetu oraz aktualną wartość procentową; pinch i przyciski współdzielą zoom. Test UI sprawdza 100% → 150% → 100% i reset. Pozostają ręczne testy VoiceOver/Voice Control/Switch Control. |
| Q03 | Akcje zdjęć mają kontekst numeru w wartości dostępności, zachowują widoczną nazwę i minimum 44 pt; zdjęcie główne ma trait zaznaczenia. |
| Q04 | Dekoracyjna tarcza jest ukryta dla dostępności. Bazowe okno pozostaje ukryte dla AX podczas blokady; test UI kontroluje brak kontrolek kolekcji. |
| Q05 | Regresja na iOS 17.5 i 27.0. Osobno pozostaje fizyczny iPhone, testy technologii wspomagających i realnej blokady/odtworzenia backupu. Duo zgodnie z decyzją właściciela nie jest kryterium tego etapu. |

Domyślna waluta nowych szkiców to PLN dla języka polskiego, USD dla pozostałych obsługiwanych języków. Kod preferowanej waluty jest również pierwszy na liście walut. Edycja zachowuje istniejącą walutę, także gdy nie została określona.

## Układ kodu

- `App/Security`: blokada, uwierzytelnienie, osłona okna, protected-data lifecycle.
- `Domain/{Collection,Wishlist,Wear,Documents}`: szkice, reguły i błędy.
- `Persistence/{Schemas,Migrations,Mappings,Operations,Queries}`: snapshoty, migracje, mapowania, zapis i zakresy odczytu.
- `Services/Assets` i `Services/Imaging`: pliki, ochrona, import i przygotowanie obrazów.
- `Shared/Components` i `Shared/Presentation`: współdzielone kontrolki, opisy zegarków i prezentacja błędów.
- `Features`: funkcje aplikacji; adaptery UIKit są obok funkcji, które ich potrzebują.

Nie dodano bibliotek zewnętrznych ani zmiany minimalnej wersji iOS. Snapshoty nie zostały „odduplikowane”; ich utrwalona tożsamość jest konieczna do migracji.

## Interpretacja testów dostępności

Sprawdzenia nie wyłączają całej kategorii kontrastu ani hit region. Wyjątki dotyczą systemowych nieaktywnych kontrolek, przewijalnego pola wyszukiwania iOS, celowo dwuwierszowego skrótu notatki z przetestowanym pełnym widokiem oraz nieinteraktywnych akapitów PDFKit. Elementy schowane za paskiem nawigacji lub zakładek nie są oceniane jako widoczny tekst.

Xcode 27 błędnie oznacza kontrast natywnego przycisku w szklanej kapsule: wyeksportowany zrzut pokazuje biały tekst na ciemnym tle. Wyjątek dotyczy tylko systemowych przycisków Cancel/Done wewnątrz navigation bar na iOS 26+. Dowód: [native-cancel-contrast.png](screenshots/implementation/native-cancel-contrast.png). Własne przyciski i treści aplikacji nadal podlegają sprawdzeniu. Zgłoszenia kontrastu bez istniejącego elementu AX są zachowywane ze zrzutem jako `AUDIT_MANUAL_CONTRAST`; wymagają osobnego przeglądu i nie są uznawane za potwierdzony poprawny kontrast. Tekst pomocniczy używa jawnego, nieprzezroczystego koloru dobranego do obu motywów.

## Weryfikacja wymagająca urządzenia

1. Na iPhonie z kodem, w podpisanej testowej kompilacji z osobnym identyfikatorem aplikacji, sprawdzić `.complete` dla bazy, WAL/SHM, zdjęć, miniatur i dokumentów; powtórzyć po aktualizacji istniejącej kolekcji, kolejnych zapisach i odtworzeniu WAL/SHM. SwiftData nie udostępnia odpowiednika opcji `NSPersistentStoreFileProtectionKey`; domyślną klasę Core Data opisuje [dokumentacja Apple](https://developer.apple.com/documentation/coredata/nspersistentstorefileprotectionkey). Sam entitlement nie jest dowodem ustawienia klasy przez framework.
2. Zablokować telefon z otwartym dokumentem i edytorem, odczekać okres wygaszania kluczy iOS, potwierdzić odmowę odczytu plików. Odblokować: dane i szkic pozostają dostępne, bez resetu bazy i ujawnienia prywatnego okna.
3. Sprawdzić zimny start i powrót po restarcie telefonu, anulowanie Face ID/kodu, systemowy picker oraz przełącznik aplikacji.
4. Wykonać backup i odtworzenie testowej kolekcji; potwierdzić komplet zdjęć, dokumentów i historii. Sam znacznik `isExcludedFromBackup = false` nie dowodzi odtworzenia.
5. VoiceOver: Read All, rotor PDF i fokus po arkuszach; Voice Control i Switch Control: akcje zdjęć/zoom; duży tekst, Reduce Motion, oba motywy, Increase Contrast i Reduce Transparency.
6. Instruments na dużej kolekcji: 1k/10k/50k wpisów, 100 zdjęć, 500 zegarków, szczytowa pamięć i main-thread stalls. Syntetyczny PDF nie reprezentuje dowolnego dokumentu z nieznanego źródła.

To są pozostałe warunki odbioru urządzeniowego i pomiarowego, a nie testy zaliczone przez symulator. Nie instalowano nowej kompilacji na prywatnym telefonie ani nie wykonywano na nim operacji na kolekcji.

## Pomiary automatyczne

W przebiegu Debug na iPhone 12 / iOS 17.5 import syntetycznych PDF-ów 1/100/1000 stron zajął odpowiednio około 1,34/0,74/2,12 ms. Przygotowanie dokumentu i miniatury pierwszej strony: 0,76/0,43/1,31 ms. Plik 1000-stronicowy miał około 473 KB; wynik nie opisuje np. wielowarstwowego skanu o rozmiarze 20 MB.

Istniejący test statystyk zmierzył 1k/10k/50k wpisów na około 0,82/6,92/32,38 ms, wobec 26,90/266,80/1322,62 ms wariantu porównawczego. Ten algorytm był już zoptymalizowany przed tym wdrożeniem. Nowe zmiany ograniczają pobierane rekordy i powtarzane przeliczenia w widokach; powyższych liczb nie należy przedstawiać jako pomiaru ich przyspieszenia ani czasu renderowania całego ekranu.

## Wyniki regresji

| Przebieg | Zakres | Wynik |
|---|---|---|
| iPhone 12, iOS 17.5 — pełny | 37 testów jednostkowych i 20 UI | 17 istniejących testów funkcjonalnych UI bez błędów. Audyt wykrył przycinanie etykiety waluty; poprawiono je i ponowiono test. [Pełny log przed tą poprawką](verification/full-ios17-before-currency-wrap.log). |
| iPhone 18 Pro, iOS 27.0 — pełny | 37 testów jednostkowych i 20 UI | 0 błędów, 2 jawnie pominięte sprawdzenia. [Log](verification/full-ios27.log). |
| iOS 17.5 — po końcowym przeglądzie | 38 testów jednostkowych oraz 6 UI: dostępność, dokumenty, blokada i podgląd życzenia | 0 błędów, 2 pominięte sprawdzenia. [Log](verification/final-ios17.log). |
| iOS 17.5 — finalny kontrast wartości pól | Lista, oba edytory, historia, statystyki, ustawienia | 0 błędów; zachowane dwa zgłoszenia bez elementu AX do ręcznego przeglądu. [Log](verification/final-accessibility-ios17.log). |
| iOS 27.0 — po końcowym przeglądzie | 38 testów jednostkowych oraz te same 6 UI | 0 błędów, 2 pominięte sprawdzenia. [Log](verification/final-ios27.log). |

Końcowe testy obejmują także nowy przypadek ponownego pojawienia się edytora po zatwierdzeniu pliku, odświeżanie ochrony SQLite po zapisie i końcowy podział plików. Macierz funkcjonalna obejmuje PL/EN, jasny/ciemny motyw oraz standardowy/AX XXXL tekst.

Pominięte są test metadanych Data Protection na symulatorze oraz audyt ekranu blokady w chwili, gdy systemowy proces uwierzytelnienia przejmuje pierwszy plan (`com.apple.accessibilityAudit -902`). Istniejący test ukrycia kolekcji przez osłonę przechodzi. To dwa konkretne ograniczenia, nie wyłączone testy zapisu lub migracji.

Nierozpoznane węzły kontrastu mają zachowane dowody: [iOS 17](screenshots/implementation/contrast-manual-ios17-1.png), [iOS 27](screenshots/implementation/contrast-manual-ios27-1.png). Widoczny materiał pod paskiem nawigacji/zakładek wymaga oceny w Accessibility Inspector; brak elementu AX uniemożliwia wiarygodne automatyczne przypisanie zgłoszenia do kontrolki. Zrzuty pochodzą wyłącznie z testowych kolekcji.

Weryfikacja statyczna: `swift-format lint --strict`, `git diff --check`, poprawny plist projektu/entitlements, zgodność wszystkich plików Swift z referencjami i Sources w Xcode, identyczne deklaracje schematów V1/V2/V3. Pozostałe ostrzeżenie narzędzia dotyczy pominiętej ekstrakcji App Intents, z którego aplikacja nie korzysta.

Dodatkowa kontrola eksploracyjna PL na iOS 17.5 potwierdziła domyślne PLN w nowym życzeniu, PLN przed pozostałymi kodami oraz zaznaczenie tej waluty na pełnej liście. [Zrzut listy](screenshots/implementation/currency-pl.png). Wybór innej waluty i powrót do formularza sprawdzono w izolowanej bazie testowej.

Logi tekstowe znormalizowano wyłącznie przez usunięcie końcowych spacji w wierszach. Oryginalne pakiety XCTest pozostają w `/tmp/MojeZegarki-complete17.xcresult`, `/tmp/MojeZegarki-complete270.xcresult`, `/tmp/MojeZegarki-final-review17.xcresult`, `/tmp/MojeZegarki-final-core17.xcresult` i `/tmp/MojeZegarki-final-review270.xcresult`.
