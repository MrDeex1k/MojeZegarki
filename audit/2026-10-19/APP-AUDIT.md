# Audyt aplikacji Moje Zegarki

Data: 19 października 2026. Branch: `audit/app-review`. Kod bazowy: `6efe09d7a50fffc246fecebf0210641a59cfea50`. Zakres: lokalna aplikacja iPhone, iOS 17+, SwiftUI, SwiftData, UIKit, import zdjęć i dokumentów. Właściciel potwierdził brak backendu, konta i synchronizacji.

Najpierw warto naprawić czytelność notatek i etykiety dostępności, następnie domknąć ścieżki błędów zapisu i sprzątania plików. Obecny podział na `App`, `Domain`, `Persistence`, `Services` i `Features` jest sensowny. Proponowane porządki rozwijają ten układ; nie wymagają migracji do innego frameworka ani dodania warstw dla hipotetycznego backendu.

Raport zawiera propozycje, nie wdrożone poprawki. P0 oznacza blokadę podstawowego zadania lub utratę danych, P1 istotne utrudnienie bez praktycznego obejścia, P2 problem z obejściem lub ograniczoną ekspozycją, P3 usprawnienie utrzymania. Nie potwierdzono P0 ani P1. Ryzyka modelu zagrożeń mają osobną skalę i nie są automatycznie potwierdzonymi podatnościami.

## Zakres i dowody

Wykorzystano `swiftui-pro`, `swiftdata-pro`, `swift-accessibility-skill`, oba lokalne audytory dostępności, `security-threat-model`, `agent-device` oraz `testing-react-native-apps:dogfood`. Przegląd źródeł i obserwacje eksploracyjne są opisane osobno; ustalenia dogfood wynikają z zachowania i drzewa dostępności aplikacji.

- Xcode 27.1, Swift 6.4; target projektu pozostaje iOS 17, tryb języka Swift 6.
- Build aktualnego kodu zakończył się powodzeniem. Ostrzeżenia o pominiętej ekstrakcji App Intents nie są błędami aplikacji niekorzystającej z tego frameworka.
- 23 istniejące testy jednostkowe: 23 zaliczone, 0 błędów. Obejmują m.in. migracje V1/V2, transakcje, kaskadowe usuwanie, import, statystyki i blokadę.
- 17 istniejących testów UI: 17 zaliczonych, 0 błędów. Zestaw obejmuje CRUD kolekcji, listę życzeń/Undo/reordering, historię, dokumenty, zdjęcia, blokadę i macierz kalendarza PL/EN × jasny/ciemny × standardowy/duży tekst na iOS 17.5.
- Eksploracja: iPhone 12, iOS 17.5, aktualny build Debug, angielski interfejs, tekst standardowy i Accessibility XXXL. Wyłącznie baza uruchamiana przez `--uitesting`; nie używano prywatnej kolekcji.
- Logi testów: [unit-tests.log](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/unit-tests.log), [ui-tests.log](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/ui-tests.log). Pakiety wyników XCTest pozostają w `/tmp/MojeZegarki-audit-unit.xcresult` i `/tmp/MojeZegarki-audit-ui.xcresult`.
- Nie wykonano pełnej sesji VoiceOver, Voice Control ani Switch Control na fizycznym urządzeniu, audytu w aplikacji Accessibility Inspector ani profilowania Instruments. Drzewo AX nie zastępuje tych sprawdzeń.

## Potwierdzone problemy i ścieżki błędów

### A01 Długie notatki pod dokumentem są ucinane

**P2, odtworzone w UI.** [DocumentPreviewView.swift:33](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Documents/DocumentPreviewView.swift:33).

`Text(notes)` dzieli `VStack` z podglądem i nie ma własnego przewijania ani rozwinięcia. Przy AX XXXL notatka o długości 770 znaków kończy się wielokropkiem. Zapisane dane są kompletne, lecz użytkownik nie może ich w całości przeczytać w podglądzie; obejściem jest otwarcie edycji. Długie notatki ograniczają też miejsce na dokument.

**Poprawka:** wydzielić notatkę do osobnego, przewijalnego ekranu szczegółów, otwieranego przyciskiem „Pokaż całą notatkę”. Pod podglądem można zachować ograniczony skrót. Przekazać pełny tekst również do widoku dostępnego dla VoiceOver i umożliwić zaznaczanie tekstu. Nie obejmować `PDFView` drugim pionowym scrollem.

**Weryfikacja:** 0, 1, 770 i 5000 znaków, PL/EN, standard/AX XXXL; pełna treść dostępna bez wejścia w edycję, podgląd PDF pozostaje przewijalny. Ryzyko regresji: zagnieżdżone gesty i układ podglądu.

Dowody: [podgląd po zapisie](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/document-long-notes.png), [nagranie](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/videos/document-notes.mp4).

### A02 Przycisk dodawania dni traci znaczenie przy dużym tekście

**P2, potwierdzone w drzewie AX i UI.** [WearEditorView.swift:85](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wear/WearEditorView.swift:85).

W gałęzi `isAccessibilitySize` przycisk pokazuje `+N`. Jego etykietą AX jest dokładnie `+1`, bez informacji o zapisie dni noszenia. Krótki napis może pozostać wizualnie, ale potrzebuje pełnej nazwy i wartości dla technologii wspomagających.

Minimalna propozycja po istniejącym `Button`, przed `.disabled`:

```swift
.accessibilityLabel(log != nil ? Text("Save") : Text("Add wear days"))
.accessibilityValue(log == nil ? Text("Selected days: \(newDays.count)") : Text(""))
```

Użyć istniejących tłumaczeń, a przy wdrożeniu sprawdzić zgodność nazwy z Voice Control; opcjonalne alternatywne komendy powinny być zlokalizowane. **Weryfikacja:** wybrać zegarek i dzień, sprawdzić nazwę, wartość oraz aktywację w VoiceOver/Voice Control. Oczekiwane: znaczenie akcji jest jasne mimo wizualnego `+1`. Ryzyko regresji: niskie, dotyczy semantyki.

Dowód: [przycisk +1](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/wear-save-ax5.png).

### A03 Dwie ścieżki animacji pomijają Reduce Motion

**P2, potwierdzone statycznie; zachowanie przy włączonej preferencji wymaga ręcznej weryfikacji.** [WearView.swift:234](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wear/WearView.swift:234), [WishlistView.swift:176](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wishlist/WishlistView.swift:176).

Automatyczne przewijanie historii wykonuje do trzech `withAnimation`, a przełączenie trybu porządkowania listy życzeń także używa bezwarunkowej animacji. Pozostałe komponenty, np. statystyki i szybkie oznaczanie noszenia, już uwzględniają Reduce Motion.

**Poprawka:** dodać w obu widokach `@Environment(\.accessibilityReduceMotion) private var reduceMotion` i zastąpić wskazane wywołania przez `withAnimation(reduceMotion ? nil : .default) { ... }`. Zachować istniejące anulowanie zadania oraz sprawdzanie wybranego dnia. Rozważyć osobno ograniczenie ponownych przewinięć po pomiarze ich zachowania.

**Weryfikacja:** Reduce Motion on/off, wybór wpisanego i pustego dnia oraz wejście/wyjście z porządkowania. Oczekiwane: identyczny cel nawigacji bez wymuszonego ruchu po wyłączeniu animacji. Ryzyko regresji: timing wstawiania wierszy `List`.

### A04 Awaria sprzątania zdjęć pomija sprzątanie dokumentów

**P2, potwierdzona ścieżka błędu w kodzie; bez wymuszania awarii systemu plików.** [CollectionStore.swift:162](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Persistence/CollectionStore.swift:162).

`reconcilePhotos()` najpierw sprząta zdjęcia, a dopiero później pobiera referencje i sprząta dokumenty. Błąd pierwszego serwisu kończy całą metodę. Przy kolejnym uruchomieniu powtarzający się problem ze zdjęciami może stale blokować usuwanie osieroconych dokumentów. Ma to znaczenie dla miejsca na dysku i pozostałości po usuniętych fakturach.

**Poprawka:** zmienić nazwę na `reconcileAssets`; pobrać referencje z bazy i wykonać dwie niezależne próby sprzątania. Zebrać i zalogować wyniki obu zamiast kończyć po pierwszym błędzie. Nie uruchamiać sprzątania bez poprawnie odczytanej listy referencji danej kategorii.

**Weryfikacja:** kontrolowany błąd serwisu zdjęć, osierocony dokument i poprawny dokument referencjonowany. Oczekiwane: dokument osierocony usunięty, poprawny zachowany, błąd zdjęć raportowany. Ryzyko regresji: omyłkowe usuwanie plików przy niepełnym odczycie bazy; potrzebny test integracyjny.

### A05 Błąd odczytu w saveWish może pozostawić niezapisane mutacje

**P2, potwierdzona struktura ścieżki błędu; scenariusz wymaga błędu `fetch`.** [CollectionStore.swift:226](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Persistence/CollectionStore.swift:226).

Metoda najpierw wstawia lub modyfikuje `WishlistItem`, a następnie wykonuje rzucający `context.fetch` w celu wyznaczenia pozycji. `rollback()` chroni dopiero późniejsze `context.save()` w `persistChanges()`. Awaria wcześniejszego odczytu może zostawić częściowy obiekt w kontekście współdzielonym z innymi operacjami; następny zapis może go utrwalić.

**Poprawka:** wykonać walidację i odczyt pozycji przed `context.insert` i przed modyfikacją istniejącego modelu. Alternatywnie objąć całą mutującą operację wspólną obsługą wycofania. Zachować aktualną kolejność elementów przy edycji bez zmiany priorytetu.

**Weryfikacja:** wstrzyknąć błąd odczytu listy rówieśników; po nieudanej operacji `context.hasChanges` i stan istniejącego elementu powinny odpowiadać stanowi przed operacją. Następny zapis innej encji nie może utrwalić niedokończonego życzenia. Ryzyko regresji: pozycjonowanie i Undo.

## Bezpieczeństwo i prywatność

Pełny model: [MojeZegarki threat model](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/MojeZegarki-threat-model.md). Poniższe punkty są usprawnieniami ochrony i polityki produktu, nie dowodem zdalnego obejścia zabezpieczeń.

| ID | Priorytet | Miejsce | Proponowana praca i warunek odbioru |
|---|---|---|---|
| S01 | P2 | `Services/PhotoStore.swift:41`, `Services/DocumentStore.swift:72`, `Persistence/CollectionStore.swift:11` | Ustalić wspólną politykę Data Protection dla bazy, WAL/SHM, zdjęć i faktur. Aktualnie załączniki jawnie używają klasy dostępnej po pierwszym odblokowaniu. Jeśli celem jest niedostępność plików przy każdym zablokowaniu urządzenia, rozważyć `.complete` wraz z obsługą protected-data lifecycle. Testować na fizycznym urządzeniu; nie zmieniać samej opcji zapisu w oderwaniu od SwiftData. |
| S02 | P2 | `Persistence/CollectionStore.swift:15`, `README.md`, ekran prywatności | Doprecyzować różnicę między brakiem synchronizacji a backupem iOS. `Application Support` jest domyślnie uwzględniane w backupie. Zachować możliwość odtworzenia danych; nie wyłączać backupu kolekcji automatycznie. Odtwarzalne miniatury można wyłączyć po dodaniu regeneracji. |
| S03 | P2 | `Services/DocumentStore.swift:38`, `Features/Documents/DocumentPreviewView.swift:71` | Zbadać limity złożoności PDF i koszt dekodowania obrazów: wiele stron, bardzo duże wymiary źródła, uszkodzone dane, limit bajtów na granicy. Obecne 20 MB i downsampling to dobre zabezpieczenia, ale nie pomiar kosztu parsera. Odbiór: brak nieograniczonego wzrostu pamięci i responsywny UI na zestawie testowym. |
| S04 | P3 | `App/MojeZegarkiApp.swift:84` | Zastąpić publiczne logowanie dowolnego `localizedDescription` kategorią błędu i prywatnym szczegółem. Odbiór: log użytkowy nie ujawnia ścieżek ani nazw dokumentów. Nie stwierdzono obecnie wycieku treści dokumentów. |

Klasa `completeUntilFirstUserAuthentication` pozostawia plik dostępny po ponownym zablokowaniu telefonu, po pierwszym odblokowaniu od restartu. Opisuje to [Apple Data Protection](https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication). Domyślne objęcie `Application Support` kopiami zapasowymi opisuje [Apple File System](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively).

## Optymalizacje do zweryfikowania pomiarem

Nie zmierzono spadków FPS, nadmiernego zużycia pamięci ani czasu startu produkcyjnego. Poniższe punkty wskazują realne koszty widoczne w kodzie i eksperymenty, które mają rozstrzygnąć, czy refaktor jest opłacalny.

| ID | Miejsce | Koszt i propozycja | Pomiar i ochrona przed regresją |
|---|---|---|---|
| O01 | [WearView.swift:10](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wear/WearView.swift:10), [WearStatisticsView.swift:7](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wear/WearStatisticsView.swift:7) | Widok ogólny pobiera historię, potem filtruje/grupuje ją w pamięci. Statystyki mapują całą historię i sortują ranking w `body`. Ograniczyć zapytania do aktywnego zegarka/okresu, rozdzielić podsumowanie, kalendarz i listę wybranego dnia. | Instruments SwiftUI/Time Profiler i alokacje dla 1k/10k/50k wpisów. Pamiętać, że `.all` wymaga pełnego zakresu, a usunięcia i zmiana przypisania wpisu muszą odświeżać wyniki. |
| O02 | [TimepieceEditorView.swift:150](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Collection/TimepieceEditorView.swift:150), [WearStatisticsView.swift:127](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wear/WearStatisticsView.swift:127) | Zwykłe `HStack` i `VStack` tworzą wszystkie zdjęcia/wiersze rankingu. Rozważyć leniwe stosy i osobny `WatchStatisticsRow`. Limit 10 zdjęć dotyczy pojedynczego importu, nie całego zegarka. | Pamięć oraz liczba inicjalizacji przy 100 zdjęciach lub 500 zegarkach; sprawdzić stabilność przewijania, fokus, wysokości i ładowanie miniaturek. |
| O03 | [DocumentPreviewView.swift:67](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Documents/DocumentPreviewView.swift:67), [PhotoView.swift:94](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Collection/PhotoView.swift:94) | Odczyt bajtów jest w actorze, lecz utworzenie `PDFDocument` i część przygotowania `UIImage` odbywają się na ścieżce UI. Najpierw zmierzyć otwieranie trudniejszych plików. | Sprawdzić main-thread stalls i peak memory. Nie przenosić niesendowalnego `PDFDocument` przez granice aktorów; rozważyć URL do PDFKit i osobny etap walidacji. |
| O04 | [CollectionView.swift:15](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Collection/CollectionView.swift:15), [WishlistView.swift:24](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wishlist/WishlistView.swift:24), [TimepieceDetailView.swift:226](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Collection/TimepieceDetailView.swift:226) | Wielokrotne filtrowanie `visible`, `search.trimmed`, grup priorytetów i sortowanie zdjęć. Najpierw obliczać wynik raz na wykonanie `body`; dopiero później rozważać cache z jawną invalidacją. | Sprawdzić wyszukiwanie po edycji nazwy, zmianie statusu/priorytetu i zmianie zdjęcia głównego. Nie wprowadzać stanu pochodnego bez pełnej aktualizacji. |

Istniejący test `testStatisticsAtCollectionScale` zmierzył sam algorytm dla 50 tys. wpisów na ok. **32 ms** w tym uruchomieniu Debug, wobec ok. 1,30 s dla wbudowanego wariantu porównawczego. To nie jest pomiar całego ekranu ani wynik Release; uzasadnia zachowanie istniejącej deduplikacji dni.

## Wspólne elementy i struktura plików

### R01 Wydzielić powtarzające się komponenty formularzy

**P2 utrzymanie.** [TimepieceEditorView.swift:94](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Collection/TimepieceEditorView.swift:94), [WishlistView.swift:255](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wishlist/WishlistView.swift:255), [DocumentsView.swift:174](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Documents/DocumentsView.swift:174).

- `CurrencyPicker`: wspólna lista walut i lokalizowana nazwa. Obecnie edytor kolekcji pokazuje kod i nazwę, lista życzeń sam kod.
- `OptionalDateField`: włącznik daty i `DatePicker`, z etykietami przekazanymi jako lokalizowalne zasoby. Zachować odrębne reguły dat zakupu, dokumentu i noszenia.
- `DiscardChangesConfirmation`: wspólny mechanizm zamknięcia zmienionego draftu, bez przejmowania całej logiki edytora.
- Istniejące `.appError` zastosować również w edytorze i szczegółach kolekcji, gdzie ta sama konstrukcja alertu jest powtórzona.

**Odbiór:** te same zasady anulowania i walidacji, PL/EN, bez utraty szkicu. Zachować ceny jako kanoniczny zapis `Decimal`; nie zastępować walidacji `Double` ani pobłażliwym `NumberFormatter`.

### R02 Wydzielić zarządzanie importem i cyklem życia szkicu

**P2 utrzymanie i niezawodność.** [TimepieceEditorView.swift:12](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Collection/TimepieceEditorView.swift:12), [WishlistView.swift:222](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Wishlist/WishlistView.swift:222), [DocumentsView.swift:89](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Features/Documents/DocumentsView.swift:89).

Trzy edytory utrzymują pokrewne flagi `importing`, `committed`, listę plików i asynchroniczne sprzątanie. Lista życzeń ma dodatkowy wyjątek dla pełnoekranowego podglądu, a edytor zegarka zadanie z przyciskiem Stop.

Wydzielić mały obiekt sesji importu: identyfikatory utworzonych plików, zadanie, `commit(retaining:)`, `discard()` i anulowanie. Zakończenie edycji powinno rozstrzygać o życiu plików; samo chwilowe zniknięcie widoku nie powinno być jedynym sygnałem. Nie ma dowodu, że obecna poprawka podglądu usuwa pliki — to obszar do zmniejszenia ryzyka kolejnej regresji.

**Odbiór:** import → podgląd → powrót → zapis; import → Categories → powrót; Stop w trakcie importu; anulowanie; błąd zapisu; zamknięcie po zapisie; restart i reconciliation. Żaden plik nadal używany przez draft lub bazę nie może zostać usunięty.

### R03 Rozdzielić ekrany od komponentów i integracji UIKit

**P3 utrzymanie.** `WishlistView.swift` mieści listę i edytor; `DocumentsView.swift` listę, edytor, draft i route; `PhotoView.swift` miniaturę, pełny ekran i cache; `WearView.swift` ekran oraz integrację z `UIScrollView`. To są odrębne odpowiedzialności, które można przenosić bez zmiany zachowania.

Wydzielić `WishlistEditorView`, `DocumentEditorView`, `WatchPhotoPreview`, `ImageLoader`, `WearScrollBehavior` i `WearScrollAnchor`. W samym `WearView` wydzielić filtr, przycisk podsumowania i wiersz wpisu. Wspólny `WatchIdentityLabel` może obsłużyć markę/model/status w kolekcji, historii i liście życzeń, zachowując świadome różnice stylu. Nie przenosić wszystkich drobnych prywatnych typów do globalnego katalogu `Helpers`.

UIKit obejmuje również `App/LockShield.swift` i `Features/Wear/WearView.swift`, nie tylko podgląd dokumentów. Ich sprawdzenie jest częścią zakresu audytora UIKit.

### R04 Podzielić operacje bazy i mapowania bez przebudowy stosu

**P3 utrzymanie.** [CollectionStore.swift:4](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Persistence/CollectionStore.swift:4), [CollectionSchemaV3.swift:124](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Persistence/CollectionSchemaV3.swift:124), [WishlistDraft.swift:29](/Users/jakubbatycki/KOD/MojeZegarki/MojeZegarki/Domain/WishlistDraft.swift:29).

Zachować jeden `CollectionStore`/`ModelContainer` i główny kontekst. Rozdzielić implementację na rozszerzenia Collection, Wishlist, Wear i Documents oraz osobny plik utrwalania/reconciliation. Wydzielić plan migracji i aliasy modeli z pliku schematu V3. Mapowania z modeli SwiftData do draftów umieścić w `Persistence/Mappings`, aby pliki domenowe nie musiały znać konkretnej wersji schematu.

**Zachować historyczne schematy V1/V2 i utrwalony układ typów modeli V3.** Podobieństwo snapshotów nie jest zwykłą duplikacją do usunięcia wspólną klasą bazową. Zmiany struktury modeli wymagają osobnej oceny migracji. Nie dodawać repozytoriów i protokołów dla każdej klasy bez konkretnej potrzeby testowej.

### Proponowany układ docelowy

```text
MojeZegarki/
  App/
    MojeZegarkiApp.swift
    RootView.swift
    Security/                 # AppLock, authenticator, LockShield, LockScreen
  Domain/
    Collection/               # TimepieceDraft, PhotoDraft, opcje, błędy
    Wishlist/                 # draft, priorytet, walidacja linku
    Wear/                     # WearDay, WearStatistics, WearError
    Documents/                # DocumentAsset, DocumentKind, błędy
  Persistence/
    CollectionStore.swift
    Operations/               # rozszerzenia store dla obszarów aplikacji
    Schemas/                  # niezmienione snapshoty V1, V2, V3
    Migrations/               # CollectionMigrationPlan
    Mappings/                 # model SwiftData -> draft
    Models.swift              # aliasy aktualnego schematu
  Services/
    Assets/                   # PhotoStore, DocumentStore, ImportedImage
    Imaging/                  # ImageLoader
  Shared/
    Components/               # CurrencyPicker, OptionalDateField, WatchIdentityLabel
    Presentation/             # AppError, potwierdzanie porzucenia zmian
  Features/
    Collection/               # lista, szczegóły, edytor
      Components/             # sekcja zdjęć, wiersz kolekcji
    Wishlist/                 # lista i edytor w oddzielnych plikach
      Components/
    Wear/
      Components/             # kalendarz, wiersz, filtr, przyciski
      UIKit/                  # WearScrollAnchor i zachowanie przewijania
    Documents/                # lista, edytor, podgląd
      UIKit/                  # PDFPreview, ZoomableDocumentImage
    Settings/
  Resources/
Tests/                        # osobne grupy domeny, persistence, usług, blokady
UITests/                      # osobne grupy Collection, Wishlist, Wear, Documents, Accessibility
```

Przenosić etapami i aktualizować jawne wpisy `project.pbxproj`. Nie zmieniać przy okazji nazw encji, kluczy UserDefaults, nazw plików magazynu ani identyfikatorów testów UI. `AppLock` można pozostawić w `Services`, jeśli to przyjęta konwencja — istotne jest grupowanie odpowiedzialności, nie jedna obowiązkowa nazwa katalogu.

## Dostępność i luki w weryfikacji

| ID | Priorytet | Co sprawdzić lub uzupełnić |
|---|---|---|
| Q01 | P2 | Dodać `performAccessibilityAudit` do istniejącego targetu UI: lista kolekcji, edytory, statystyki, podgląd dokumentu i blokada. Obecne testy sprawdzają istnienie/hittability, ale nie uruchamiają tego audytu. Nie filtrować automatycznie wszystkich problemów kontrastu czy hit region. |
| Q02 | P2 | `DocumentPreviewView.swift:106`: sprawdzić powiększanie obrazu bez pinch, aktualny zoom i nawigację po obrazie w VoiceOver/Voice Control/Switch Control. Jeśli systemowy scroll view nie zapewnia wymaganej obsługi, dodać dostępne przyciski powiększania i resetu, z aktualizacją wartości. Sam brak własnych przycisków nie dowodzi niedostępności gestów systemowych. |
| Q03 | P2 | `TimepieceEditorView.swift:156`: przyciski „Set as main”/„Remove photo” są powtarzane bez wskazania zdjęcia i bez jawnego minimum obszaru dotyku. Zmierzyć rzeczywisty hit region, dodać kontekst pozycji/zdjęcia oraz odstęp lub `minHeight: 44` tam, gdzie potwierdzi się zbyt mały obszar. |
| Q04 | P3 | `LockShield.swift:105`: dekoracyjna ikona jest odczytywana jako `lock.shield`; drzewo AX to potwierdziło. Dodać `.accessibilityHidden(true)`. Sprawdzić fokus po anulowaniu uwierzytelnienia oraz ukrycie bazowego okna z aktywnym arkuszem. |
| Q05 | P2 | Uzupełnić walidację o fizyczny iPhone oraz iOS 27.x, szczególnie blokadę, app switcher, powrót z systemowego pickera, kontekst UIKit i materiały. Testy na iOS 17.5 nie potwierdzają gałęzi `.glassProminent` ani zachowania nowego systemu. |

Przykład poprawki Q04:

```swift
Image(systemName: "lock.shield")
    .font(.system(size: 54, weight: .light))
    .foregroundStyle(Color("AccentColor"))
    .accessibilityHidden(true)
```

**🔴 Blocks Assistive Tech:** nie potwierdzono blokera. **🟡 Degrades Experience:** A01 i A02 odtworzone, A03 potwierdzone statycznie. **🟠 Incomplete Support:** Q01–Q05 obejmują brakującą weryfikację i ograniczone poprawki. **✅ Verified in code:** natywne kontrolki i arkusze, jawne etykiety głównych akcji, alternatywy listowe kalendarza dla dużego tekstu, opis procentu wykresu, obsługa Reduce Motion w statystykach i szybkim przycisku noszenia.

**Do sprawdzenia na urządzeniu:** VoiceOver Read All, rotor i zaznaczanie tekstu PDF, fokus po otwarciu/zamknięciu arkuszy i blokady, Voice Control „Show names/numbers”, Switch Control, maksymalny tekst, Reduce Motion, Reduce Transparency, Increase Contrast i oba motywy. Oczekiwane: wszystkie podstawowe akcje osiągalne, pełne treści czytelne, brak nieoczekiwanego przeskakiwania fokusu. Nutrition Label readiness: brak podstaw do pełnej deklaracji na podstawie tego zakresu testów. Napisy i audiodeskrypcja filmu nie dotyczą obecnego produktu.

## Kolejność prac

1. A01–A03: notatki, pełna etykieta zapisu dni, Reduce Motion; małe zmiany z testami regresji zachowania.
2. A04–A05: odporność reconciliation i atomowość ścieżki błędu `saveWish`, z kontrolowanymi błędami w testach.
3. S01–S02 i Q01–Q05: decyzja o ochronie i backupie oraz brakująca walidacja dostępności/urządzenia.
4. R01–R04: komponenty, sesja importu, podział plików i operacji, osobny mały commit na etap. Najpierw ekstrakcje bez zmiany zachowania.
5. O01–O04 i S03: pomiary na większym zestawie danych i trudniejszych plikach; wdrażać optymalizacje, które poprawiają zmierzone wyniki.

Nie zalecam podnoszenia minimum iOS, zastępowania SwiftData przez Core Data, przerabiania historycznych schematów ani usuwania UIKit wyłącznie dla jednolitości. `tabItem` i starsze nazwy API należy rozpatrywać w kontekście minimum iOS 17; brak nowego `Tab` nie jest sam w sobie usterką tej aplikacji.
