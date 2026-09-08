# Roadmapa

Stan: fazy 0–3 zaimplementowane. Bieżące wyniki i ograniczenia opisuje raport wersji FREE. Test fizycznego iPhone’a i publikacja pozostają do wykonania.

## Faza 0 — fundament (zaimplementowany)

Utworzyć projekt SwiftUI dla iPhone’a z minimum iOS 17.0, lokalną bazą SwiftData, strukturą katalogów, String Catalogs PL/EN, zasobami, testami i preview. Zatwierdzone założenia obsługi plików: HEIC z zapasowym JPEG i limit 20 MB na dokument.

## Faza 1 — kolekcja (zaimplementowana)

Timepiece, lista, szczegóły, formularze, wyszukiwanie, zdjęcia z wyborem głównego, lokalny zapis, archiwum, przywracanie i usuwanie zależności.

## Faza 2 — noszenie i lista życzeń (zaimplementowana)

Szybkie oznaczanie noszenia, wiele zegarków dziennie bez duplikatów, lista historii i liczba dni. Lista życzeń ze zdjęciem oraz bezpieczne przenoszenie do kolekcji.

## Faza 3 — dokumenty i gotowość FREE (zaimplementowana; testy symulatorów zaliczone)

PDF i zdjęcia dokumentów, podgląd, prywatne pliki, usuwanie i błędy. Opcjonalna blokada dostępu. Weryfikacja PL/EN, VoiceOver, Dynamic Type, motywów, offline i trwałości danych.

To zamyka zakres funkcjonalny MVP. Nie dodawać na tym etapie serwisów, przypomnień, rozbudowanego kalendarza ani eksportu/importu.

## Faza 4 — TestFlight i App Store

- Główne urządzenie: iPhone 15 Pro właściciela, na jego koncie Apple.
- Dodatkowe urządzenia rodzinne: iPhone 15 i iPhone 17.
- Faktyczne wersje systemów nie zostały jeszcze podane.
- Sprawdzić minimalny wspierany system oraz systemy urządzeń testowych; modele telefonów nie są informacją o zainstalowanym iOS.
- TestFlight, poprawki, zatwierdzenie ikony, materiały PL/EN, informacje wsparcia i prywatności.
- Publikacja FREE przed Premium, bez paywalla.

## Faza 5 — prototyp Premium

Zweryfikować synchronizację modeli i plików, migracje, konflikty, aktywację i wygaśnięcie subskrypcji oraz ponowne łączenie danych. Test synchronizacji wymaga dwóch urządzeń zalogowanych na to samo konto iCloud; rodzinne telefony na innych kontach nie zastępują takiego testu. Nie zmieniać kont rodzinnych bez osobnej decyzji właścicieli.

## Faza 6 — Premium

Po zatwierdzeniu polityki subskrypcji i udanym prototypie: miesięczny StoreKit 2, paywall, przywracanie zakupów, prywatna synchronizacja, obsługa błędów i braku iCloud. Ustalić cenę przed publikacją.

## Poza zatwierdzonym zakresem

Serwisy, przypomnienia, rozbudowany kalendarz, OCR, widgety, App Intents, watchOS, dedykowany iPad/macOS i zaawansowane statystyki. Backend dopiero przy rzeczywistej potrzebie web/Android, własnych kont lub funkcji publicznych; nie jest obowiązkową fazą projektu.
