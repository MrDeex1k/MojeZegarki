# Testy eksploracyjne aplikacji Moje Zegarki

| Pole | Wartość |
|---|---|
| Data | 19 października 2026 |
| Aplikacja | My Watches, `pl.jakubbatycki.MojeZegarki` |
| Platforma | iPhone 12 Simulator, iOS 17.5, 390 × 844 pt |
| Build | Debug z kodu `6efe09d`, Xcode 27.1 |
| Sesja | `mojezegarki-audit` |
| Dane | Izolowane `--uitesting`, fixtures zdjęcia/dokumentu/noszenia |
| Konfiguracje | EN, standardowy tekst oraz Accessibility XXXL |

## Wynik

| Poziom | Liczba odtworzonych problemów |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 1 |
| Razem | 3 |

Obserwacje poniżej wynikają z UI, screenshotów i drzewa AX. Nie przypisano problemom przyczyny na podstawie źródeł; mapowanie na kod jest w raporcie głównym. Nie ustalano z góry minimalnej liczby usterek.

## ISSUE 001 Długa notatka dokumentu jest ucięta

- Severity: medium. Category: visual/content/accessibility. Ekran: podgląd dokumentu PDF.
- Nagranie: [document-notes.mp4](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/videos/document-notes.mp4).
- Oczekiwane: cały zapisany tekst da się przeczytać w trybie przeglądania, również przy największym tekście.
- Obserwowane: tekst ma wielokropek; brak przycisku rozwinięcia i osobnego przewijania notatki. Pełny tekst jest w AX, ale użytkownik korzystający wzrokowo musi wejść do edycji.

Kroki:

1. Uruchomić izolowany fixture dokumentu z językiem EN i `UICTContentSizeCategoryAccessibilityXXXL`.
2. Collection → Document watch → Documents → Test invoice. [Przed zmianą](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/document-before.png).
3. Document actions → Edit. Zastąpić notatkę tekstem `Private invoice note. ` powtórzonym 35 razy, łącznie 770 znaków. [Edycja](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/document-edit-notes.png).
4. Save. [Ucięta treść](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/document-long-notes.png).

Obejście: otworzyć edycję i przeczytać pełną notatkę. Brak dowodu utraty zapisanych danych.

## ISSUE 002 Przycisk zapisu wybranych dni ma nazwę plus jeden

- Severity: medium. Category: accessibility/content. Ekran: Wear days, duży tekst.
- Nagranie: N/A, statyczny problem etykiety przy danym stanie.
- Oczekiwane: nazwa dostępności mówi, że akcja dodaje dni noszenia.
- Obserwowane: drzewo AX pokazuje wyłącznie `[button] "+1"`; bez wybranych dni jest `+0`.

Kroki:

1. Uruchomić fixture historii, EN, Accessibility XXXL.
2. Wearing → Add wear days. [Stan początkowy](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/wear-editor-ax5.png).
3. Wybrać TestBrand Calendar watch i 1 października 2026.
4. Sprawdzić przycisk w prawym górnym rogu i jego etykietę AX. [Stan +1](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/wear-save-ax5.png).

Obejście: znaczenie można wywnioskować z ekranu. Nie stwierdzono nieskuteczności samego zapisu. Pełna weryfikacja komendy głosowej wymaga Voice Control na urządzeniu.

## ISSUE 003 Dekoracyjna ikona blokady ujawnia nazwę symbolu

- Severity: low. Category: accessibility. Ekran: Collection locked.
- Nagranie: N/A, statyczny problem semantyki.
- Oczekiwane: czytnik odczytuje tytuł, instrukcję i Unlock; dekoracja nie tworzy dodatkowego przystanku.
- Obserwowane: drzewo AX zawiera obraz `lock.shield`, obok poprawnego tekstu „Collection locked”.

Kroki:

1. Uruchomić izolowaną bazę z włączoną blokadą i największym tekstem.
2. Anulować systemowe uwierzytelnienie, bez wpisywania kodu.
3. Sprawdzić obraz i nazwę w AX. [Ekran blokady](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/lock-ax5.png).

W tej konfiguracji Unlock pozostał widoczny i hittable. Nie potwierdzono blokady dostępu przez duży tekst ani obejścia uwierzytelnienia.

## Przepływy bez stwierdzonej usterki w eksploracji

- Otwarcie zdjęcia zegarka na pełnym ekranie; widoczny obraz i przycisk Done, bez paska kart podglądu. [Dowód](/Users/jakubbatycki/KOD/MojeZegarki/audit/2026-10-19/screenshots/photo-preview.png).
- Wejście w historię, wybór zegarka i dnia; licznik zmienia się z `+0` na `+1`.
- Otwarcie PDF, odczyt tekstu dokumentu w AX, otwarcie edycji i zapis notatki.
- Anulowanie uwierzytelnienia pozostawia ekran zablokowany; AX nie odsłania listy kolekcji.

## Ograniczenia

Testy nie obejmują fizycznej biometrii, pełnej pracy VoiceOver, Voice Control, Switch Control, realnego backupu/restore ani porównania wydajności Release. Nie wykonano fuzzingu plików. Nie traktowano komunikatów automatyzacji o wolnym drzewie AX jako dowodu spowolnienia aplikacji. Testy regresji XCTest są raportowane oddzielnie w raporcie głównym.
