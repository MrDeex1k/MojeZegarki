# TestFlight 0.8.0 — przygotowanie dystrybucji

Stan przygotowania: 22.09.2026. Celem jest zamknięta beta dla 15–20 osób, początkowo 3 testerów. Nie zgłaszamy jeszcze publicznej wersji do App Store.

## Zatwierdzone ustalenia

| Pole | Wartość |
| --- | --- |
| Osoba odpowiedzialna | Jakub Batycki |
| Status właściciela | Osoba prywatna, nie przedsiębiorca — deklaracja właściciela |
| Nazwa PL / EN | Moje Zegarki / My Watches: Daily wrist — nazwa EN zapisana w App Store Connect; lokalizacja PL do potwierdzenia |
| Bundle ID | `pl.jakubbatycki.MojeZegarki` |
| Wersja / pierwszy build | `0.8.0` / `1`; zwiększać build przy kolejnych wysyłkach |
| Feedback Email / kontakt aplikacji | `mywatches@mail.batycki.dev` — działanie potwierdzone przez właściciela |
| Ikona | Obecny AppIcon zatwierdzony |
| Funkcje | Lokalny FREE; bez konta, synchronizacji i subskrypcji |
| Języki interfejsu | PL i EN, zgodnie z preferencjami systemowymi użytkownika |
| Nazwa zakładki | Harmonogram (PL), Wearing (EN) |
| Docelowe rynki sklepu | Polska i pozostałe kraje; dostępność sklepu nie uruchamia dystrybucji TestFlight |
| Termin | Nieustalony; najpierw TestFlight |

Język podstawowy metadanych w App Store Connect: **English (U.S.)**. Polska lokalizacja metadanych pozostaje do przygotowania; interfejs aplikacji obsługuje już PL i EN.

## Gotowe materiały

- [Metadane PL](metadane-pl.md): podtytuł, keywords, tekst promocyjny, opis sklepu, opis bety i „Co testować”.
- [Metadane EN](metadane-en.md): odpowiedniki angielskie.
- [Screeny PL/EN](screenshots/README.md): rzeczywisty interfejs z fikcyjnymi danymi, jasny i ciemny motyw.
- [Scenariusze testów fizycznych](testy-urzadzen.md).

Opisy sklepowe i screeny są materiałami na późniejszą publikację. TestFlight ma oddzielny opis bety i pole Feedback Email; Apple pozwala im różnić się od późniejszych metadanych sklepu. [Apple: informacje testowe](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

## Stan dystrybucji

- Członkostwo Apple Developer Program aktywne; Bundle ID zarejestrowany.
- Rekord **My Watches: Daily wrist** utworzony, SKU `mywatches-ios`.
- Build **0.8.0 (1)** wysłany i przetworzony 17.09.2026. Informacje testowe i deklaracja szyfrowania zapisane w App Store Connect.
- Grupa wewnętrzna **Właściciel** otrzymała build. Właściciel potwierdził instalację na prywatnym iPhonie przez TestFlight.
- Brak potwierdzenia zakończenia zewnętrznego TestFlight App Review lub testów znajomych. Publiczna wersja App Store nie została wydana.

## Weryfikacja brancha — 18.09.2026

- Pełny zestaw na symulatorze iPhone 18 Pro / iOS 27: **16 testów jednostkowych i 5 testów UI, bez błędów**.
- Testy zapisu wielu dni obejmują pomijanie duplikatów, trwałość po ponownym otwarciu bazy, zmianę czasu i odrzucenie całej nieprawidłowej partii przed zapisem.
- Kompilacja Release dla ogólnego urządzenia iOS bez podpisywania: **BUILD SUCCEEDED**.
- Wcześniejsza ręczna weryfikacja wyboru wielu dni na iOS 17.5: zapis trzech dni i zachowanie wpisów po ponownym uruchomieniu.
- Testy automatyczne nie zastępują sprawdzenia aktualizacji istniejącej instalacji TestFlight na fizycznym urządzeniu. Schemat bazy pozostaje bez zmian.

## Wersja 0.8.2 (3)

Następny build zawiera statystyki noszenia z wyborem okresu i zegarka, porównanie zegarków, kalendarz w historii oraz poprawki zgłoszone przez testerów. Dodano bezpośrednie przenoszenie z listy życzeń i poprawiono układ Harmonogramu oraz szczegółów zegarka. Schemat danych pozostaje bez zmian.

Wersja 0.8.1 (2) została wysłana do TestFlight 18.09.2026. W projekcie aplikacji ustawiono teraz 0.8.2 (3) dla Debug i Release. Build 3 wymaga podpisanego archiwum i wysłania przez właściciela.

## Następne kroki

1. Dokończyć udostępnienie bety zewnętrznym testerom i zebrać wyniki scenariuszy fizycznych urządzeń.
2. Zmiany Harmonogramu na tym branchu powstały po wysłaniu buildu 1: wybór wielu dni, ciaśniejsze odstępy i poprawiona typografia. Nie są jeszcze częścią zainstalowanej bety.
3. Projekt przygotowano do kolejnej wysyłki jako `0.8.2 (3)`. Przygotować nowe archiwum i zweryfikować zachowanie danych przy aktualizacji. Przy następnych wysyłkach dalej zwiększać numer buildu.
4. Przed publiczną publikacją uzupełnić metadane sklepu, strony wsparcia i prywatności oraz aktualne zrzuty ekranu.

## Informacje do uzupełnienia

- Adresy e-mail 3 testerów — przekazać przy zaproszeniach; nie umieszczać w publicznym repozytorium.
- Hosting oraz docelowe HTTPS URL stron wsparcia i prywatności. Nie wybrano adresów; nie publikowano stron. Działający e-mail nie zastępuje Support URL ani Privacy Policy URL.
- Odpowiedzi formularzy App Store Connect, w tym klasyfikacja wiekowa i prywatność, przed odpowiednim etapem dystrybucji.

## Kontakt i prywatność danych kontaktowych

Właściciel potwierdził, że jest osobą prywatną i nie jest przedsiębiorcą. Aktualny zakres to wyłącznie TestFlight — według Apple taka dystrybucja nie oznacza działania jako trader w App Store. Przy późniejszej publikacji sklepowej deklaracja DSA powinna odzwierciedlać charakter działalności związanej z aplikacją; sam brak firmy nie rozstrzyga jej automatycznie. Wybór `This is not a trader account` nie wymaga podawania publicznych danych kontaktowych DSA. Nie zmieniano ustawień App Store Connect. [Apple: DSA](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

Każda aplikacja może mieć własny adres wsparcia/Feedback Email. Tutaj używamy `mywatches@mail.batycki.dev`. Przekierowanie na jedną skrzynkę rozdziela adresy, ale do porządkowania poczty potrzebne będą reguły lub osobne skrzynki.

Kontakt dla review: **Jakub Batycki**, **mywatches@mail.batycki.dev**, telefon uzupełniany prywatnie w App Store Connect. Dane App Review nie są widoczne klientom. Przy przyszłej publikacji w UE osobno deklaruje się status DSA; dane kontaktowe traderów są publiczne. Konto indywidualne samo w sobie nie rozstrzyga tego statusu. [Apple: App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [Apple: DSA](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

## Beta App Review — notatka EN

> My Watches: Daily wrist is a local, offline iPhone app for managing a personal watch collection. No account or sign-in is required. There are no purchases or subscriptions in this build. Start by adding a watch using the plus button; only brand and model are required. You can then add photos, log wear days, manage a wishlist and attach PDF/image documents. Optional Face ID/device passcode protection is available in Settings and uses the reviewer's device authentication. The app ships with an empty collection; screenshots use fictional demonstration data. Supported languages are English and Polish. This submission is for TestFlight external beta testing only.

Sign-in required: **No**. Nie tworzyć konta demonstracyjnego — aplikacja nie ma logowania.
