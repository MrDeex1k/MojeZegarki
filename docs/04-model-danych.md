# Model danych

CollectionSchemaV2 zawiera Timepiece, TimepiecePhoto, WearLog, DocumentItem i WishlistItem. Schemat V1 pozostaje zamrożony; migracja V1 → V2 zachowuje zegarki, ceny, statusy i relacje zdjęć. Zgodność z przyszłą synchronizacją CloudKit nadal wymaga osobnej weryfikacji.

## Timepiece

- Techniczne: `id`, `createdAt`, `updatedAt`, `status` (domyślnie posiadany).
- Wymagane od użytkownika: `brand`, `modelName`.
- Opcjonalne: `deviceKind`, `movementType`, `categoryIDs`, `referenceNumber`, `serialNumber`, `purchaseDate`, `purchasePrice`, `currencyCode`, `seller`, `notes`.
- Relacje: zdjęcia, dokumenty, wpisy noszenia.
- Status: `owned`, `sold`, `destroyed`; dwa ostatnie tworzą widok Archiwum.

Rodzaj urządzenia: tradycyjny lub smartwatch. Mechanizm oddzielnie: manualny, automatyczny, kwarcowy, inny, nieznany. Kategorie wielokrotnego wyboru: diver, garniturowy, sportowy, pilot, field, codzienny. Kategorie nie są techniczną certyfikacją zegarka.

Brak wartości opcjonalnej odróżniać od ceny zero lub jawnego wyboru „nieznany”. Cena jest zapisana jako kanoniczny dziesiętny String z kodem waluty; walidacja i formatowanie korzystają z Decimal bez konwersji do Double. Numer seryjny nie jest kluczem unikalnym.

## TimepiecePhoto

`id`, relacja do zegarka, względny identyfikator pliku, typ pliku, kolejność, oznaczenie zdjęcia głównego, `createdAt`. Dla zegarka ze zdjęciami wskazywać jedno główne; miniatury są danymi odtwarzalnymi. Brak limitu liczby zdjęć.

## WearLog

`id`, relacja do zegarka, `calendarDay`, `createdAt`. Bez godzin i sesji w MVP. Unikalność domenowa: zegarek + dzień. Kilka różnych zegarków w tym samym dniu jest dozwolone.

Dzień oznacza datę kalendarzową wybraną przez użytkownika, nie chwilę UTC. Zapis: gregoriański klucz yyyy-MM-dd. Wyświetlanie odtwarza lokalną datę; zmiana strefy po zapisie nie przesuwa dnia. Testy obejmują zmianę strefy i dzień zmiany czasu. Ponowne „noszę dzisiaj” nie tworzy duplikatu. Liczba dni noszenia wynika z historii. Archiwizacja nie usuwa wpisów. Zegarek z archiwum może otrzymać wpis z wcześniejszego dnia; dzisiejszy wpis wymaga przywrócenia do kolekcji.

## DocumentItem

`id`, relacja do jednego zegarka, `displayName`, `fileType`, `fileSize`, względny identyfikator pliku, `createdAt`; opcjonalnie `kind`, `documentDate`, `notes`. Typy dokumentów: zakup, gwarancja, serwis, inny. Przechowywanie dokumentu serwisowego nie oznacza modułu obsługi serwisów.

PDF lub zdjęcie, lokalna kopia niezależna od źródła. Bez dokumentów współdzielonych i dokumentów całej kolekcji. Brak limitu liczby dokumentów. Limit pojedynczego dokumentu wynosi 20 000 000 bajtów. SHA-256 oryginalnych bajtów zapobiega ponownemu dodaniu identycznego dokumentu do tego samego zegarka.

## WishlistItem

`id`, `brand`, `modelName`, `createdAt`, `updatedAt`; opcjonalnie zdjęcie, `url`, `targetPrice`, `currencyCode`, `priority`, `notes`.

Przeniesienie otwiera formularz z istniejącymi danymi. Dopiero pomyślne utworzenie zegarka usuwa element listy życzeń; anulowanie i błąd zachowują wpis oraz zdjęcie.

## Usuwanie i prywatność

- Archiwizacja zachowuje zdjęcia, dokumenty i noszenie; jest odwracalna.
- Trwałe usunięcie zegarka usuwa zależne rekordy i pliki po potwierdzeniu.
- Usunięcie pojedynczego załącznika usuwa jego lokalny plik.
- Nie logować faktur, numerów seryjnych ani prywatnych danych zakupu.
- Serwisy, terminy gwarancji i przypomnienia nie mają osobnego modelu w MVP.
