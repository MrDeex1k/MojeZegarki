# FREE 0.2.0 — implementacja i weryfikacja

Data: 2026-09-08. Swift 6, Xcode 26.6, minimum iOS 17.0, interfejs dla iPhone’a.

## Zaimplementowany zakres

- Lokalna kolekcja, edycja, wyszukiwanie, zdjęcia główne, Archiwum i trwałe usuwanie.
- Noszenie: wiele zegarków dziennie, jeden wpis na zegarek/dzień, wpisy historyczne, edycja, usuwanie, filtr i liczba dni. Zegarki z archiwum przyjmują wcześniejsze dni.
- Lista życzeń: zdjęcie, cena/waluta, link, priorytet, notatki. Przeniesienie zapisuje nowy zegarek i usuwa życzenie w jednej transakcji; anulowanie zachowuje źródło.
- Dokumenty: import z Plików lub biblioteki zdjęć, prywatna kopia, limit 20 000 000 bajtów, metadane, podgląd PDF/obrazu i usuwanie. Dokumenty i historia konkretnego zegarka mają osobne panele nawigacji, aby zachować zgodność z iOS 17.
- Opcjonalna blokada Face ID/kodem urządzenia, ponowne blokowanie po przejściu do tła, zasłanianie także formularzy i podglądów.
- PL/EN, odmiana liczby dni, lokalne formaty cen/dat, ikona i manifest prywatności.

FREE nie zawiera synchronizacji, subskrypcji, paywalla ani eksportu/importu kolekcji. Systemowy backup urządzenia pozostaje oddzielną funkcją iOS.

## Dane i zgodność

V1 pozostaje zamrożonym schematem. V2 dodaje WearLog, WishlistItem i DocumentItem. Test migracji otwiera rzeczywistą bazę V1 i sprawdza zachowanie zegarka, statusu, ceny oraz relacji zdjęcia.

Edytory pracują na szkicach; autosave SwiftData jest wyłączony. PDF jest zachowywany bajt w bajt. Obrazy kolekcji: maksymalnie 2400 px i miniatury 600 px. Dokumenty zdjęciowe: maksymalnie 4000 px, HEIC z JPEG jako formatem zapasowym.

Pliki są najpierw zapisywane do katalogu roboczego. Udany zapis bazy zachowuje potrzebne pliki; anulowanie usuwa nowe pliki. Przy uruchomieniu sprzątane są pozostałości bez referencji. Usuwanie zegarka jawnie usuwa relacje i pliki, uwzględniając zachowanie SwiftData na iOS 17.

## Testy automatyczne

Zestaw zawiera 14 testów domeny/integracji i 5 testów UI:

- walidacja wymaganych pól i kwot, trwałość po otwarciu bazy ponownie;
- migracja V1 → V2, archiwizacja i kaskadowe usuwanie;
- przetwarzanie zdjęć, miniatury, sprzątanie i zachowanie zdjęcia przy przenoszeniu życzenia;
- dni kalendarzowe, strefy czasowe, zmiana czasu, duplikaty, przyszłe daty i reguły Archiwum;
- dokumenty: prywatna kopia, identyczność PDF, limity, duplikaty, błędne pliki i usuwanie;
- blokada: wymagane uwierzytelnienie, anulowanie, trwałość preferencji, unieważnienie spóźnionego wyniku i współbieżnych prób;
- UI: kolekcja, język polski, anulowanie formularzy, przeniesienie życzenia, historia, podgląd/edycja/usuwanie dokumentu i ukrycie kolekcji po starcie z aktywną blokadą.

Testy UI mają osobną bazę. Test podglądu dokumentu tworzy syntetyczny PDF wyłącznie w DEBUG z flagami testowymi; nie weryfikuje dostawców systemowej aplikacji Pliki. Logika importu pliku jest dodatkowo sprawdzana testem integracyjnym.

Wyniki końcowe:

| Weryfikacja | Wynik |
| --- | --- |
| iPhone 15 Pro, iOS 17.5 | Poprzedni pełny przebieg: 18/18; bieżące testy domeny/integracji: 14/14 |
| iPhone 17, iOS 26.5 | 19/19 testów zaliczonych |
| Release, generic iOS, bez podpisu | BUILD SUCCEEDED |
| Katalog tłumaczeń | Wszystkie wyodrębnione klucze mają PL i EN |
| Paczka Release | Minimum 17.0, rodzina urządzeń iPhone, ikona i manifest; bez testowych wtyczek |

Lokalne wyniki Xcode: `.build/Free-delivery-iOS17.xcresult` oraz `.build/Free-delivery-iOS26.xcresult`. Wyniki wcześniejszych prób służyły diagnozie i nie zastępują tych końcowych raportów.

Po dodaniu testu anulowania uwierzytelniania zestaw domeny/integracji na iOS 17.5 przechodzi 14/14. Ponowny pełny przebieg zaliczył pozostałe testy, ale test UI podglądu PDF dwukrotnie zatrzymał się na oczekiwaniu XCTest na bezczynność `PDFView`; nie zapisano więc dla tego runtime wyniku 19/19. Ten sam bieżący zestaw przechodzi 19/19 na iOS 26.5.

Ręcznie na iOS 17.5: otwarcie systemowego importera, wybór syntetycznego PDF z „Na moim iPhonie”, zapis metadanych i podgląd. Treść faktury jest czytelna wizualnie i dostępna w drzewie dostępności. Wcześniej sprawdzono również szybkie noszenie i odczyt liczby dni w polskiej wersji.

Symulacja Face ID przez agent-device zwróciła `UNSUPPORTED_OPERATION` dla tego runtime. Nie zaliczono ręcznego testu biometrii. Brak tej możliwości nie ogranicza opisanych testów logiki blokady ani automatycznego sprawdzenia zasłony prywatności.

## Granice weryfikacji i następny etap

- Fizyczny iPhone 15 Pro, rodzinny iPhone 15 i iPhone 17 pozostają do sprawdzenia. Testy symulatora obejmują iOS 17.5 i 26.5; iOS 17.0 jest minimum kompilacji, ale nie był uruchomiony w tej sesji.
- Testy logiki blokady używają kontrolowanego mechanizmu uwierzytelnienia. Automatyczny test UI sprawdza zasłonę i drzewo dostępności. Biometrię oraz kod trzeba także sprawdzić na fizycznym telefonie.
- Do sprawdzenia na telefonie: rzeczywiste faktury i duże zdjęcia, mała ilość miejsca, dostawcy Plików, VoiceOver, największy Dynamic Type i praca bez sieci.
- W Xcode trzeba wybrać Team i skonfigurować podpisywanie. Kompilacja Release bez podpisu nie jest gotową paczką do wysłania do App Store.
- Do TestFlight/App Store: finalna nazwa i identyfikator, konto App Store Connect, adresy wsparcia/prywatności, materiały PL/EN, deklaracje prywatności oraz dystrybucja.
- Premium/iCloud jest osobnym przyszłym etapem; lokalne ścieżki zdjęć i dokumentów nie synchronizują się automatycznie.

Zakres funkcjonalny FREE jest zaimplementowany. Kryteria wydania wymagające fizycznego telefonu i dystrybucji pozostają otwarte.
