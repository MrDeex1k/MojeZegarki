# TestFlight 0.8.0 — przygotowanie dystrybucji

Stan przygotowania: 17.09.2026. Celem jest zamknięta beta dla 15–20 osób, początkowo 3 testerów. Nie zgłaszamy jeszcze publicznej wersji do App Store.

## Zatwierdzone ustalenia

| Pole | Wartość |
| --- | --- |
| Osoba odpowiedzialna | Jakub Batycki |
| Status właściciela | Osoba prywatna, nie przedsiębiorca — deklaracja właściciela |
| Nazwa PL / EN | Moje Zegarki / My Watches — dostępność do potwierdzenia w App Store Connect |
| Bundle ID | `pl.jakubbatycki.MojeZegarki` |
| Wersja / pierwszy build | `0.8.0` / `1`; zwiększać build przy kolejnych wysyłkach |
| Feedback Email / kontakt aplikacji | `mywatches@mail.batycki.dev` — działanie potwierdzone przez właściciela |
| Ikona | Obecny AppIcon zatwierdzony |
| Funkcje | Lokalny FREE; bez konta, synchronizacji i subskrypcji |
| Języki interfejsu | PL i EN, zgodnie z preferencjami systemowymi użytkownika |
| Nazwa zakładki | Harmonogram (PL), Wearing (EN) |
| Docelowe rynki sklepu | Polska i pozostałe kraje; dostępność sklepu nie uruchamia dystrybucji TestFlight |
| Termin | Nieustalony; najpierw TestFlight |

Proponowany język podstawowy metadanych w App Store Connect: **English (U.S.)**, z dodatkową lokalizacją Polish, żeby EN był językiem zapasowym. To propozycja konfiguracji, nie zmiana języka aplikacji. Język interfejsu i metadanych nie jest sztywno przypisany do kraju pobytu użytkownika.

## Gotowe materiały

- [Metadane PL](metadane-pl.md): podtytuł, keywords, tekst promocyjny, opis sklepu, opis bety i „Co testować”.
- [Metadane EN](metadane-en.md): odpowiedniki angielskie.
- [Screeny PL/EN](screenshots/README.md): rzeczywisty interfejs z fikcyjnymi danymi, jasny i ciemny motyw.
- [Scenariusze testów fizycznych](testy-urzadzen.md).

Opisy sklepowe i screeny są materiałami na późniejszą publikację. TestFlight ma oddzielny opis bety i pole Feedback Email; Apple pozwala im różnić się od późniejszych metadanych sklepu. [Apple: informacje testowe](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

## Weryfikacja lokalna

Build Debug dla symulatora i Release dla urządzenia zakończone powodzeniem bez podpisywania; oba raportują `0.8.0 (1)`. Sprawdzono limity metadanych, ikonę 1024 × 1024 bez przezroczystości oraz 12 screenów 1320 × 2868. Testy na fizycznych urządzeniach pozostają do wykonania; przy tej zmianie wersji i dokumentacji nie uruchamiano ponownie pełnego zestawu testów automatycznych.

## Kolejność uruchomienia bety

1. Właściciel aktywuje płatne członkostwo Apple Developer Program. Obecnie nieaktywne — wysyłka do TestFlight jest zablokowana. [Apple: dystrybucja](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).
2. W Xcode wybrać Team właściciela. Zarejestrować Bundle ID i utworzyć rekord aplikacji w App Store Connect. Proponowany wewnętrzny SKU: `mywatches-ios`.
3. Sprawdzić dostępność nazw przy zapisie rekordu/lokalizacji. Publiczne wyszukiwanie nie potwierdza rezerwacji nazwy. Znaleziono inną aplikację [My Watches](https://apps.apple.com/ve/app/my-watches/id980408690?l=en-GB); nazwa EN może wymagać alternatywy. Nie zmieniono jej bez decyzji właściciela. [Apple: tworzenie aplikacji](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app).
4. Przygotować podpisane archiwum Release 0.8.0 (1), zweryfikować je w Organizer i wysłać do App Store Connect. Dotychczasowe buildy bez podpisu nie stanowią paczki gotowej do wysyłki. Przed wysyłką sprawdzić akceptację używanej wersji Xcode/SDK przez Apple.
5. Uzupełnić deklarację szyfrowania dla rzeczywistego buildu, informacje bety i dane kontaktowe Apple. Nie ustawiono automatycznie deklaracji eksportowej. Finalną paczkę sprawdzić także pod kątem manifestu prywatności.
6. Właściciel wykonuje test instalacji i podstawowych scenariuszy na swoim iPhonie.
7. Utworzyć prywatną grupę testerów zewnętrznych, np. `Early testers`, i przekazać pierwszy build do TestFlight App Review. Dopiero po akceptacji zaprosić 3 osoby, następnie rozszerzyć grupę do 15–20. Znajomym nie trzeba nadawać dostępu administracyjnego do App Store Connect. [Apple: testerzy zewnętrzni](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers).
8. Zebrać błędy i wyniki testów fizycznych; następne poprawki wysyłać jako kolejne numery buildu. Publiczny App Store pozostaje oddzielną decyzją.

## Informacje do uzupełnienia

- Team ID po aktywacji członkostwa; rekord aplikacji i potwierdzone nazwy.
- Numer telefonu kontaktowego dla Apple — wpisać bezpośrednio w App Store Connect, nie w repozytorium.
- Adresy e-mail 3 testerów — przekazać przy zaproszeniach; nie umieszczać w publicznym repozytorium.
- Hosting oraz docelowe HTTPS URL stron wsparcia i prywatności. Nie wybrano adresów; nie publikowano stron. Działający e-mail nie zastępuje Support URL ani Privacy Policy URL.
- Odpowiedzi formularzy App Store Connect, w tym klasyfikacja wiekowa i prywatność, przed odpowiednim etapem dystrybucji.

## Kontakt i prywatność danych kontaktowych

Właściciel potwierdził, że jest osobą prywatną i nie jest przedsiębiorcą. Aktualny zakres to wyłącznie TestFlight — według Apple taka dystrybucja nie oznacza działania jako trader w App Store. Przy późniejszej publikacji sklepowej deklaracja DSA powinna odzwierciedlać charakter działalności związanej z aplikacją; sam brak firmy nie rozstrzyga jej automatycznie. Wybór `This is not a trader account` nie wymaga podawania publicznych danych kontaktowych DSA. Nie zmieniano ustawień App Store Connect. [Apple: DSA](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

Każda aplikacja może mieć własny adres wsparcia/Feedback Email. Tutaj używamy `mywatches@mail.batycki.dev`. Przekierowanie na jedną skrzynkę rozdziela adresy, ale do porządkowania poczty potrzebne będą reguły lub osobne skrzynki.

Kontakt dla review: **Jakub Batycki**, **mywatches@mail.batycki.dev**, telefon uzupełniany prywatnie w App Store Connect. Dane App Review nie są widoczne klientom. Przy przyszłej publikacji w UE osobno deklaruje się status DSA; dane kontaktowe traderów są publiczne. Konto indywidualne samo w sobie nie rozstrzyga tego statusu. [Apple: App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [Apple: DSA](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

## Beta App Review — notatka EN

> My Watches is a local, offline iPhone app for managing a personal watch collection. No account or sign-in is required. There are no purchases or subscriptions in this build. Start by adding a watch using the plus button; only brand and model are required. You can then add photos, log wear days, manage a wishlist and attach PDF/image documents. Optional Face ID/device passcode protection is available in Settings and uses the reviewer's device authentication. The app ships with an empty collection; screenshots use fictional demonstration data. Supported languages are English and Polish. This submission is for TestFlight external beta testing only.

Sign-in required: **No**. Nie tworzyć konta demonstracyjnego — aplikacja nie ma logowania.
