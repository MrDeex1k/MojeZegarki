# Decyzje, ryzyka i pytania otwarte

Stan rozmowy: 2026-09-07. Zatwierdzone decyzje poniżej zastępują wcześniejsze propozycje dokumentacji.

## Decyzje zatwierdzone

- D-001: własny użytek i publikacja w App Store; właściciel pracuje ze Swiftem, to jego pierwszy własny projekt. Bez trybu szkoleniowego.
- D-002: pierwsza wersja tylko iPhone, PL i EN, native SwiftUI.
- D-003: FREE działa lokalnie bez własnego backendu.
- D-004: zegarki tradycyjne i smartwatche; rodzaj, mechanizm i kategorie osobno.
- D-005: użytkownik musi podać wyłącznie markę i model; cena wymaga waluty.
- D-006: wiele zdjęć i dokumentów PDF/zdjęciowych, prywatne kopie, bez OCR.
- D-007: wiele zegarków dziennie, jeden wpis na zegarek/dzień, bez godzin.
- D-008: posiadany/sprzedany/zniszczony; Archiwum jako filtr w MVP, zachowanie danych i przywracanie.
- D-009: lista życzeń w MVP, przeniesienie przez formularz zakupu.
- D-010: brak limitów ilościowych; brak eksportu/importu FREE.
- D-011: zakładki Kolekcja, Noszenie, Lista życzeń, Ustawienia; systemowe motywy i dostępność.
- D-012: opcjonalna blokada Face ID/kodem, domyślnie wyłączona; bez reklam i zewnętrznej analityki.
- D-013: FREE publikujemy przed Premium, bez nieczynnego paywalla.
- D-014: Premium wyłącznie za synchronizację iCloud, subskrypcja miesięczna; cena nieustalona.
- D-015: serwisy, przypomnienia i rozbudowany kalendarz poza MVP.

- D-016: minimalny system iOS 17.0, lokalna baza SwiftData.
- D-017: zdjęcia HEIC z JPEG jako formatem zapasowym, natywne Image I/O.
- D-018: maksymalnie 20 MB na pojedynczy dokument; bez limitu liczby dokumentów.

## Do doprecyzowania w odpowiednim etapie

- Blokada po przejściu do tła, historyczne wpisy archiwum i zapis dnia yyyy-MM-dd są już zaimplementowane; patrz model danych i architektura.
- Deduplicacja dokumentów przez SHA-256 w obrębie zegarka, zapis przez katalog tymczasowy i sprzątanie osieroconych plików są zaimplementowane.
- Nazwa publikacyjna, identyfikator aplikacji, konto deweloperskie, materiały i informacje wsparcia przed App Store.
- Cena Premium, wygaśnięcie subskrypcji, zachowanie danych w chmurze i konflikty przed Premium.
- Przyszłe platformy i współdzielenie nie są częścią bieżącego zakresu.

## Ryzyka i działania

- Zakres: zamknąć kryteria FREE przed integracjami i płatnościami.
- Trwałość: testować restart, brak miejsca, częściowy zapis i usuwanie plików.
- Lokalizacja: stałe identyfikatory domenowe, pełne PL/EN i odmiany liczby mnogiej.
- Brak eksportu: FREE nie ma własnej ścieżki przenoszenia danych przed wdrożeniem Premium; nie mylić tego z polityką systemowego backupu.
- CloudKit: wcześnie sprawdzić zgodność modelu; przed Premium prototyp przełączeń uprawnienia, konfliktów i migracji. Nie zakładać natychmiastowej synchronizacji ani automatycznej synchronizacji lokalnych ścieżek plików.
- Testy: iPhone 15 Pro jest na koncie właściciela, 15 i 17 należą do rodziny; przyszły test iCloud potrzebuje wspólnego konta na parze urządzeń testowych.
- Prywatność: dokumenty pozostają prywatne, bez logowania treści i zewnętrznej analityki.
