# Implementacja audytu — 3.10.2026

Zakres: wszystkie sześć etapów zaakceptowanego planu po audycie 2.10.2026. Nie zmieniono minimum iOS 17 ani schematu przechowywania danych.

## Zmiany

1. **Dokumenty:** podgląd w osobnym arkuszu z własnym NavigationStack usuwa zapętlenie układu na iOS 17.5. PDF ma ograniczony rozmiar widoku. Plik jest odczytywany i dekodowany raz w zadaniu, a brak/uszkodzenie PDF lub obrazu pokazuje czytelny stan błędu. Zapis, anulowanie i usunięcie są testowane. Formularz ostrzega przed odrzuceniem zmienionych danych.
2. **Dni noszenia:** wspólny kalendarz historii i edytora. Zapisane dni mają ✓ i nie da się dodać ich ponownie; oczekujące mają +; licznik i przycisk uwzględniają tylko nowe dni. Brak wyboru blokuje zapis. Zmiana zegarka czyści wybór. Przyszłość oraz dzisiaj dla archiwum są niedostępne. Store zachowuje walidację całej partii i idempotencję. Po zapisie pojawia się rzeczywista liczba nowych wpisów.
3. **UX:** wybór dnia przewija historię do wyników. Nagłówek kalendarza otwiera wybór daty/miesiąca/roku, a „Dzisiaj” wraca do bieżącego miesiąca. Legenda jednego zegarka opisuje noszenie zamiast liczby zegarków. Duży Dynamic Type zmienia siatkę dni w listę, układ wierszy w pionowy, a filtr pokazuje zawijany tekst. Polskie „Harmonogram” zastąpiono „Noszenie”. Menu wishlisty wyraźnie odróżnia uzupełnienie danych od szybkiego dodania. Po dodaniu jest komunikat, przejście do kolekcji i cofnięcie. Cofnięcie nie usuwa późniejszych zmian/historii.
4. **Odporność i wydajność:** błąd sprzątania plików jest logowany, ale nie blokuje poprawnej bazy; sprzątanie pozostaje przed pokazaniem edytorów. Zapytania szczegółów i edytora ograniczono do zegarka. Kolekcja współdzieli jedno zapytanie dzienne. Grupowanie historii wykonuje się raz na render. Statystyki walidują każdą unikalną datę tylko raz. Miniatury mają ograniczony cache (24 MiB / 32 obrazy) i asynchroniczne przygotowanie do wyświetlenia. Import z Photos używa reprezentacji plikowej i odczytu do 20 MB + 1 bajt; partia maks. 10 zdjęć, postęp i zatrzymanie. Zapisane częściowo zdjęcia zostają w formularzu; anulowanie formularza sprząta staging.
5. **Kod i narzędzia:** WearView rozdzielono na widoki kalendarza, edytora, statystyk, podsumowania i szybkiej akcji. Dodano `.swift-format`, skrypty formatowania/testów, `Regression.xctestplan`, timeouty i workflow dla iOS 17.5 / 27.0. Ustawienia pokazują wersję i numer builda. Projekt nadal nie ma zewnętrznych pakietów aplikacji wymagających aktualizacji.
6. **Regresja:** XCTest obejmuje trwałość, migrację, strefy/DST, duplikaty, archiwum, zdjęcia/dokumenty, cofnięcie wishlisty i scenariusze UI. Macierz UI obejmuje PL/EN × jasny/ciemny × standardowy/największy Dynamic Type i zapisuje screenshoty w xcresult.

## Uruchamianie

```sh
bash scripts/format.sh --check
IOS_DESTINATION='platform=iOS Simulator,id=<UUID>' bash scripts/test-ios.sh
```

W Xcode: Product → Test, schemat MojeZegarki, plan Regression. Testy używają osobnej bazy `CollectionUITests`; testowe fixture i przełączniki motywu są wyłącznie w Debug i wymagają `--uitesting`.

Workflow `.github/workflows/ios.yml` wymaga skonfigurowanego self-hosted runnera Apple Silicon z etykietą `xcode-27`, Xcode 27 oraz oboma runtime'ami i nazwami urządzeń z macierzy. Nie rejestruje runnera ani nie instaluje SDK automatycznie. Zweryfikowano lokalne wykonanie poleceń; zdalnego przebiegu GitHub Actions nie uruchamiano. Actions Runner musi obsługiwać Node 24 (co najmniej 2.327.1). Wyniki z `.build/*.xcresult` są publikowane jako artefakty.

Użyto aktualnych wydań [checkout 7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) i [upload-artifact 7.0.1](https://github.com/actions/upload-artifact/releases/tag/v7.0.1). Formatter pochodzi z [toolchainu Swift/Xcode](https://github.com/swiftlang/swift-format). Xcode 27.0 / Swift 6.4 pozostawiono zgodnie z weryfikacją narzędzi w raporcie audytu; numer trybu języka pozostaje 6.0.

## Ograniczenia

Symulatory nie potwierdzają fizycznego Face ID, pamięci/baterii urządzenia ani działania wszystkich zewnętrznych dostawców plików. Macierz screenshotów i etykiety dostępności nie zastępują pełnego ręcznego przeglądu VoiceOver. Minimum projektu to iOS 17.0; najstarszy zainstalowany i testowany runtime to 17.5. Pomiary statystyk są mikrobenchmarkiem algorytmu w Debug, nie pomiarem całej aplikacji ani czasu zapytań SwiftData.

## Pomiary statystyk

`FreeModuleTests.testStatisticsAtCollectionScale`, Debug, 100 zegarków, 10/100/500 odrębnych dat. Test porównuje nową implementację z poprzednią sekwencją filtrowania, parsowania dat i grupowania oraz sprawdza identyczność wyników. To pojedyncze próbki, zależne również od obciążenia hosta.

| Wpisy | iPhone 12: nowy / poprzedni | iPhone 18 Pro: nowy / poprzedni |
| --- | --- | --- |
| 1 000 | 0,84 / 27,76 ms | 0,76 / 15,22 ms |
| 10 000 | 7,16 / 278,21 ms | 7,05 / 139,03 ms |
| 50 000 | 34,89 / 1394,70 ms | 36,79 / 711,75 ms |

Źródła pomiarów: `.build/acceptance-12.log` i `.build/isolated-18.log`. Optymalizacja dotyczy obliczania statystyk; nie należy przenosić tych współczynników na szybkość całej aplikacji.

## Stabilność automatyzacji

Współdzielony iPhone 18 Pro był w trakcie testów przejmowany przez `dev.mojeauto.qa`. Logi XCTest pokazują przełączenia aplikacji i przejściowe, przeskalowane współrzędne okna. Z tego powodu końcową regresję przeniesiono na tymczasowy, czysty symulator **iPhone 18 Pro / iOS 27.0** (`1D8CB7CD-EBAF-46A7-B381-ABA84DADECA5`). Nie zatrzymywano obcej aplikacji ani jej runnera. Testy formularzy dodatkowo potwierdzają fokus klawiatury; test anulowania czeka na zamknięcie arkusza zamiast zakładać, że tap oznacza koniec animacji.


## Końcowe wyniki

| Weryfikacja | iPhone 12 / iOS 17.5 | iPhone 18 Pro / iOS 27.0 |
| --- | --- | --- |
| Testy domeny, plików, migracji i blokady | **21/21 PASS** | **21/21 PASS** |
| Testy UI (w tym osiem wariantów wyglądu) | **9/9 PASS** | **9/9 PASS** |
| Ostatnie poprawki wizualne kalendarza | **2/2 PASS** w dodatkowym przebiegu | Uwzględnione w pełnym przebiegu |
| Build Swift 6, strict concurrency | PASS | Ten sam build, PASS |
| `swift-format lint --strict`, `git diff --check` | PASS | Wspólny kod |

Pełne wyniki: `.build/acceptance-12.xcresult`, `.build/final-calendar-12.xcresult`, `.build/isolated-18.xcresult`. Kopie logów są obok tego raportu. Poprzednie, nieudane przebiegi diagnostyczne nie są zaliczane jako końcowy PASS. Końcowy przebieg iPhone 18 Pro korzystał z odizolowanego symulatora po potwierdzonym przejmowaniu oryginalnego urządzenia przez inną aplikację.

Przejrzano screenshoty standardowego i największego tekstu, PL/EN i motywów. Dzięki tej kontroli poprawiono układ wyboru zegarka, pozycję strzałek miesiąca, licznik w pasku nawigacji oraz obcinanie legendy. Wybrane dowody są w `screenshots/`.

Ręcznie przez DeviceHub potwierdzono na iPhonie 12: zapisany dzień z ✓ jest zablokowany, nowy dzień z + zwiększa licznik do 1, a zmiana zegarka czyści wybór i odświeża historię. Na iPhonie 18 Pro otwarto poprawny PDF i potwierdzono tekst dokumentu oraz działający ekran podglądu. Oznaczenia AX „covered” na iOS 27 ponownie wymagały użycia współrzędnych z aktualnego screenshotu; nie był to widoczny overlay aplikacji.

Po pracy zamknięto sesje DeviceHub i usunięto własny tymczasowy symulator QA. Na iPhonie 12 przywrócono uruchomienie zwykłej bazy i potwierdzono pustą kolekcję, bez wpisu „Audyt / Test 2026”. Dane użytkownika na oryginalnym iPhonie 18 Pro nie były modyfikowane. Testowe fixture pozostały wyłącznie w odseparowanej bazie testów na iPhonie 12; nie są widoczne w zwykłej aplikacji.

Raport opisuje lokalną weryfikację przed otwarciem PR-a. Na tym etapie nie wykonano publikacji aplikacji ani zdalnego uruchomienia workflow.
