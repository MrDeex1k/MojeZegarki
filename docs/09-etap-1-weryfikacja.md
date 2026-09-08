# Etap 1 — lokalna kolekcja

Data: 2026-09-07. Fundament projektu i lokalna kolekcja są zaimplementowane. Weryfikacja na symulatorach zakończona; fizyczny iPhone nie był jeszcze użyty do uruchomienia aplikacji.

## Dostarczone

- Natywny projekt Xcode, wspólny schemat, Swift 6, minimum iOS 17.0.
- SwiftData z wersjonowanym schematem i wyłączoną synchronizacją CloudKit.
- Lista, szczegóły, wyszukiwanie, dodawanie i edycja zegarka.
- Marka/model wymagane; pozostałe pola opcjonalne, lokalna walidacja ceny i waluty.
- Typ urządzenia, mechanizm i kategorie jako osobne dane.
- Wiele zdjęć przez PhotosPicker, HEIC/JPEG, miniatury, wybór głównego i usuwanie.
- Statusy posiadany/sprzedany/zniszczony, Archiwum i przywracanie.
- Trwałe usuwanie rekordów i zdjęć; sprzątanie przerwanych importów przy starcie.
- Katalog 89 tekstów PL/EN, systemowe motywy, podstawowe semantyki dostępności.
- Cztery zakładki; Noszenie i Lista życzeń mają na tym etapie wyłącznie puste widoki.

## Testy automatyczne

| Środowisko | Wynik |
| --- | --- |
| iPhone 15 Pro, iOS 17.5, symulator | 5 testów domeny/integracji + 2 testy UI, wszystkie zaliczone |
| iPhone 17, iOS 26.5, symulator | 5 testów domeny/integracji + 2 testy UI, wszystkie zaliczone |
| Release, SDK iPhoneOS, arm64, bez podpisywania | Kompilacja zakończona powodzeniem |

Testy obejmują ceny PL/EN i błędne dane, opcjonalność pól, zapis/odczyt bazy, edycję, archiwizację, przywrócenie, usunięcie rekordów i plików, przetwarzanie zdjęć i osierocone importy. Scenariusze UI sprawdzają dodanie → edycję → restart → archiwizację → przywrócenie → usunięcie oraz polski interfejs i anulowanie formularza.

Raporty lokalne (ignorowane przez Git):

- `.build/Stage1-final-iOS17.xcresult`
- `.build/Stage1-final-iOS26.xcresult`

Podczas testów poprawiono pozostający rekord zdjęcia po usunięciu zegarka na iOS 17. Operacja jawnie usuwa zależne modele przed zapisem. Test UI uwzględnia zagnieżdżone przyciski potwierdzenia w iOS 26.

## Weryfikacja interfejsu

Na iOS 17.5 zaimportowano wygenerowany obraz testowy przez systemowy PhotosPicker, zapisano zegarek i sprawdzono ponowne uruchomienie. Sprawdzono również dodanie kolejnego zdjęcia → wejście do kategorii → powrót → wybór zdjęcia głównego → zapis; oba zdjęcia pozostały dostępne. Sprzątanie anulowanego importu jest przypięte do zamknięcia całego edytora, a nie zniknięcia formularza przy nawigacji.

Wizualnie sprawdzono kolekcję, formularz, zdjęcia i szczegóły w języku polskim oraz szczegóły w jasnym i ciemnym motywie. Katalog tłumaczeń porównano z tekstami wyodrębnionymi podczas kompilacji — nie znaleziono brakujących kluczy. Obrazy testowe i zrzuty są lokalnymi artefaktami w `.build/`.

## Granice weryfikacji i następny etap

- Nie testowano dokładnie iOS 17.0; najstarszy dostępny i sprawdzony runtime to 17.5. Deployment target pozostaje 17.0.
- Wymagane jest jeszcze podpisanie projektu swoim Team i uruchomienie na fizycznym iPhonie.
- Pełny audyt VoiceOver/Dynamic Type, brak miejsca i awarie zapisu wymagają dalszej weryfikacji przed App Store.
- Ikona publikacyjna, dokumenty, blokada dostępu, StoreKit i CloudKit nie należą do ukończonego etapu.
- Następna faza: noszenie z historią i lista życzeń.
