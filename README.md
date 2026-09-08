# Moje Zegarki

Natywna aplikacja na iPhone’a do prywatnego zarządzania kolekcją zegarków. Projekt wykorzystuje Swift 6, SwiftUI i SwiftData, wspiera języki polski oraz angielski i docelowo trafi do App Store.

## Status

Repozytorium jest rozwijane od lokalnego modułu FREE do pierwszych testów na fizycznych urządzeniach i dystrybucji przez TestFlight. Zakres Premium, obejmujący synchronizację iCloud w miesięcznej subskrypcji, pozostaje osobnym etapem.

Szczegółowa wizja, zakres, architektura i roadmapa znajdują się w [dokumentacji projektu](docs/README.md).

## Zasady projektu

Kod źródłowy jest publicznie dostępny do wglądu, ale projekt nie jest open source. Wszelkie prawa pozostają zastrzeżone. Szczegóły określa plik [LICENSE](LICENSE).

Repozytorium nie przyjmuje Pull Requestów ani zewnętrznych fragmentów kodu. Błędy i propozycje można zgłaszać przez GitHub Issues, a pytania i rozmowy prowadzić w GitHub Discussions. Zasady opisuje [CONTRIBUTING.md](CONTRIBUTING.md).

Problemy bezpieczeństwa należy zgłaszać wyłącznie przez prywatny formularz GitHub zgodnie z [SECURITY.md](SECURITY.md).

## Platforma

- iPhone, iOS 17.0+
- Swift 6 i SwiftUI
- SwiftData z lokalnym przechowywaniem danych
- języki PL i EN
- brak zewnętrznego backendu w module FREE

## Zakres FREE

- kolekcja, wyszukiwanie, edycja, zdjęcia i Archiwum;
- szybkie oznaczanie noszenia oraz historia;
- lista życzeń i przenoszenie pozycji do kolekcji;
- prywatne dokumenty PDF i zdjęciowe;
- opcjonalna blokada Face ID lub kodem urządzenia;
- lokalne działanie bez konta i połączenia z siecią.

## Uruchomienie

Otwórz `MojeZegarki.xcodeproj`, wybierz schemat `MojeZegarki` i symulator iPhone’a. Projekt nie wymaga instalowania zależności ani uruchamiania generatora.

Do uruchomienia na fizycznym iPhonie wybierz własny Team w Signing & Capabilities. Bieżący identyfikator `pl.jakubbatycki.MojeZegarki` jest roboczy; projekt nie zawiera certyfikatów, profili provisioning ani danych konta Apple.

```sh
xcodebuild -project MojeZegarki.xcodeproj -scheme MojeZegarki \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Testy

Schemat zawiera testy domeny, trwałości danych, obsługi plików i UI. Można je uruchomić przez Product → Test w Xcode. Testy UI używają oddzielnej bazy danych i nie korzystają z kolekcji użytkownika.

Bieżący zakres FREE został sprawdzony na symulatorach iOS 17.5 i iOS 26.5. Wyniki, ograniczenia oraz testy wymagające fizycznego telefonu opisuje [raport wersji FREE](docs/10-free-weryfikacja.md).

## Struktura

- `MojeZegarki/App` — uruchomienie, nawigacja i ochrona interfejsu;
- `MojeZegarki/Features` — kolekcja, noszenie, lista życzeń, dokumenty i ustawienia;
- `MojeZegarki/Domain` — typy domenowe i walidacja;
- `MojeZegarki/Persistence` — wersjonowany schemat SwiftData i operacje zapisu;
- `MojeZegarki/Services` — przechowywanie zdjęć, dokumentów i uwierzytelnianie;
- `MojeZegarki/Resources` — zasoby, tłumaczenia PL/EN i manifest prywatności;
- `Tests`, `UITests` — testy automatyczne;
- `docs` — dokumentacja produktu i techniczna.

## Prywatność danych

Moduł FREE zapisuje kolekcję lokalnie i ma jawnie wyłączony CloudKit. Zdjęcia i dokumenty są kopiowane do prywatnego katalogu aplikacji. Projekt nie zawiera reklam, zewnętrznej analityki ani własnego backendu.

## Licencja

Source available — proprietary software. This repository is not open source. Copyright © 2026 Jakub Batycki. All rights reserved.
