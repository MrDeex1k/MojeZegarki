# Prywatność i bezpieczeństwo

## MVP FREE

- Lokalna aplikacja bez konta, reklam i zewnętrznej analityki.
- Prywatne dane: numery seryjne, faktury, sprzedawcy, ceny i historia kolekcji.
- Zdjęcia i dokumenty kopiowane do prywatnego katalogu aplikacji.
- Usuwanie zegarka lub załącznika usuwa odpowiednie rekordy i pliki; archiwizacja zachowuje je.
- Opcjonalna blokada Face ID/kodem urządzenia, domyślnie wyłączona.
- Brak ręcznego eksportu/importu zgodnie z decyzją produktową.

## Pliki i interfejs

Akceptować PDF i obsługiwane obrazy; sprawdzać zawartość i obsługiwać uszkodzone pliki, brak miejsca, cofnięte uprawnienia i przerwany zapis. Techniczny limit pojedynczego dokumentu wynosi 20 MB; brak limitów ilościowych.

Kompresować fotografie kolekcji, dbając o czytelność dokumentów zdjęciowych. PDF zachowywać bez modyfikacji. Nie zapisywać zawartości dokumentów ani prywatnych pól w logach. Blokada interfejsu nie zastępuje systemowej ochrony plików.

## Późniejsze Premium

Prywatna synchronizacja iCloud tylko dla Premium, bez publicznego udostępniania faktur i kolekcji. Brak iCloud lub sieci nie może blokować funkcji lokalnych. Stan synchronizacji pokazywać dopiero po jej implementacji.

Synchronizacja propaguje również zmiany i usunięcia; nie jest obietnicą backupu historycznego. Brak eksportu w aplikacji nie oznacza automatycznie wyłączenia systemowego backupu urządzenia — konfigurację przechowywania i backupu trzeba świadomie sprawdzić przed publikacją.

## Publikacja

Przed App Store przygotować politykę prywatności, deklaracje danych i komunikaty uprawnień zgodne z rzeczywistą implementacją. Wymagania publikacyjne i prawne zweryfikować przed dystrybucją. Ten dokument opisuje produkt i nie stanowi rozstrzygnięcia prawnego.

## Bieżąca implementacja

Manifest `PrivacyInfo.xcprivacy` deklaruje brak śledzenia i brak zbierania danych przez aplikację. UserDefaults służy do zapisu własnej preferencji blokady (powód CA92.1). Aplikacja nie ma klienta analityki ani własnego serwera. Otwarcie linku wpisanego na liście życzeń uruchamia stronę zewnętrzną; jej polityka należy do właściciela strony.

Pliki zdjęć i dokumentów mają ochronę iOS `completeFileProtectionUntilFirstUserAuthentication`. Dane pozostają w Application Support; aplikacja nie udostępnia katalogu przez File Sharing. Nie wyłączono systemowego backupu urządzenia. FREE nie oferuje własnego mechanizmu migracji kolekcji; zachowanie kopii urządzenia jest oddzielną funkcją systemu.

Blokada jest opcjonalną kontrolą dostępu do interfejsu, bez osobnego hasła aplikacji i bez własnego klucza szyfrowania. Osobne okno zasłania formularze, podgląd dokumentu i widok przełącznika aplikacji; główne okno jest wtedy wyłączone z drzewa dostępności.

Podstawa manifestu: [Apple — Required Reason API entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest). Deklaracje App Store Connect muszą odpowiadać finalnej paczce wysyłanej do dystrybucji.
