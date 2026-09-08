# Architektura techniczna

## Kierunek

SwiftUI i lokalna baza SwiftData, bez własnego backendu. Zatwierdzony minimalny system: iOS 17.0. Nie obsługujemy iOS 16.6.

Lokalnie sprawdzono Xcode 26.6 (17F113). Zainstalowane Xcode nie przesądza o minimalnym systemie aplikacji.

## Struktura implementacji

```text
App/                    — start aplikacji, nawigacja, zależności
Features/
  Collection/           — kolekcja, szczegóły, formularze, archiwum
  Wear/                 — noszenie i historia
  Wishlist/             — lista życzeń
  Documents/            — import, metadane i podgląd załączników
  Settings/             — ustawienia i blokada
Domain/                 — reguły, typy i operacje użytkownika
Persistence/            — modele bazy, zapis i migracje
Services/               — pliki, obrazy, uwierzytelnianie lokalne
Resources/              — zasoby i katalogi tłumaczeń
Tests/                  — testy domeny i integracji
UITests/                — kluczowe przepływy
```

Katalogi App, Features, Domain, Persistence, Services i Resources istnieją pod MojeZegarki/. Tests i UITests są osobnymi targetami. Wszystkie wymienione moduły FREE są zaimplementowane. Kod jest kompilowany w trybie Swift 6. Dodawać abstrakcje wraz z rzeczywistą potrzebą, bez obowiązkowego ViewModelu dla każdego widoku.

## Dane i pliki

Lokalny zapis nie zależy od sieci ani subskrypcji. Metadane i relacje należą do bazy; zdjęcia i dokumenty do prywatnego katalogu aplikacji. Używać względnych identyfikatorów plików, nie trwałych absolutnych ścieżek sandboxa. Zapewnić spójność bazy i plików przy błędzie zapisu oraz usuwaniu.

FREE używa konfiguracji SwiftData bez synchronizacji (`cloudKitDatabase: .none`). Model projektować z uwzględnieniem przyszłej kompatybilności CloudKit. Sposób synchronizacji plików wymaga prototypu; nie zakładać, że lokalna ścieżka zostanie automatycznie zsynchronizowana.

## Lokalizacja

- Natywne String Catalogs (`Localizable.xcstrings`), bez dodatkowej biblioteki i18n.
- Bazowy EN, tłumaczenie PL, wybór zgodnie z językiem aplikacji w systemie.
- Stałe identyfikatory kategorii/statusów w bazie, tłumaczone etykiety w interfejsie.
- Nie tłumaczyć marek, modeli ani notatek użytkownika.
- Obsłużyć liczby mnogie, daty, liczby, waluty, błędy, VoiceOver i komunikaty uprawnień.
- Język nie ustala waluty zakupu; brak konwersji kursów w MVP.

## Obrazy

Kompresować zdjęcia kolekcji i tworzyć miniatury. PDF zachować bez modyfikacji; dla dokumentów zdjęciowych priorytetem jest czytelność. Zatwierdzony format zdjęć: HEIC z JPEG jako formatem zapasowym, przez natywne Image I/O. WebP nie jest formatem zapisu w MVP. Parametry kompresji i rozdzielczość dobrać na próbkach, sprawdzając czytelność dokumentów. Obsługę kodowania sprawdzić na minimalnym wspieranym iOS. Limit pojedynczego dokumentu wynosi 20 MB.

## Premium — późniejszy etap

StoreKit 2 odpowiada za subskrypcję miesięczną, a CloudKit za prywatną synchronizację tego samego użytkownika iCloud. Dostęp do synchronizacji kontroluje aplikacja na podstawie uprawnienia Premium.

Automatyczna synchronizacja SwiftData nie jest sama w sobie mechanizmem subskrypcji. Przed wyborem implementacji sprawdzić FREE → Premium → FREE → Premium, dane istniejące na dwóch urządzeniach, zmianę konta, konflikty i migracje. Dopiero prototyp rozstrzyga pomiędzy synchronizacją zarządzaną a osobną warstwą CloudKit. Nie ma jeszcze zaakceptowanej szczegółowej polityki po wygaśnięciu subskrypcji.

## Blokada

Opcjonalne uwierzytelnianie lokalne Face ID/kodem urządzenia. Blokada dostępu nie zastępuje ochrony plików. Włączenie i wyłączenie blokady wymaga uwierzytelnienia. Przejście do tła blokuje dostęp; utrata aktywności od razu zasłania zawartość. Osobne okno UIKit obejmuje również formularze i podglądy, ukrywając ich dostępność. Powrót z tła uruchamia uwierzytelnienie; anulowanie pozostawia ekran blokady. Opóźniony wynik uwierzytelnienia po ponownym zablokowaniu nie otwiera kolekcji.

## Nawigacja szczegółów

Kolekcja otwiera szczegóły zegarka przez trasę opartą na UUID. Dokumenty i historia konkretnego zegarka mają osobne panele z NavigationStack. Izoluje to ich zapytania i nawigację od obserwowanego widoku szczegółów, eliminując zapętlenie aktualizacji występujące na iOS 17 przy zagnieżdżonym przejściu. Globalna historia pozostaje zakładką aplikacji.
