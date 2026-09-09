# Liquid Glass — pierwszy etap

Data: 2026-09-08. Minimum aplikacji pozostaje iOS 17.0.

## Kierunek i układ

Zdjęcie zegarka jest głównym elementem wizualnym. Nawigacja i najważniejsza akcja mają systemowy materiał, a dane i dokumenty spokojne, czytelne tło. Jedynym akcentem pozostaje kolor aplikacji.

Na ekranie szczegółów galeria prowadzi do akcji „Noszę dzisiaj”, następnie danych zegarka, historii i dokumentów. Przycisk znajduje się pod zdjęciem i nie zasłania tarczy ani wskaźnika stron. Dla zegarka bez zdjęcia akcja jest w sekcji podstawowych danych. Zegarek z archiwum nie pokazuje akcji dzisiejszego noszenia.

Ruch ogranicza się do natywnej reakcji przycisku, krótkiej zmiany stanu po zapisaniu oraz systemowych przejść nawigacji i paneli. Ograniczanie ruchu wyłącza własną animację zmiany stanu.

## Implementacja

- Natywne TabView i paski narzędzi przejmują wygląd obsługiwanego systemu. Nie dokładamy szkła do istniejącego materiału ani własnego paska zakładek.
- Edycja zegarka ma jawne miejsce primaryAction i symbol ołówka z lokalizowaną etykietą dostępności.
- Główna akcja noszenia używa glassProminent na iOS 26+. Na starszych systemach oraz przy ograniczeniu przezroczystości lub zwiększeniu kontrastu używa borderedProminent.
- Zapis nadal korzysta z istniejącej logiki: jeden wpis na zegarek i dzień; po zapisaniu przycisk jest nieaktywny i pokazuje potwierdzenie. Szybkie akcje w wierszach kolekcji pozostają kompaktowe.
- Etykieta głównej akcji może zawijać się przy większym tekście, bez skracania. W rozmiarach dostępności kapsułkę zastępuje prostokąt z zaokrąglonymi rogami, pozostawiający więcej miejsca na tekst. Jasne litery na ciemnym akcencie i ciemne na jasnym zapewniają kontrast w obu motywach. Wykorzystujemy istniejące tłumaczenia PL/EN.
- Wskaźnik stron galerii ma systemowe tło poprawiające czytelność i pojawia się tylko dla wielu zdjęć.
- Formularze, dane zakupu, zawartość dokumentów i nieprzezroczysta zasłona blokady pozostają bez efektu szkła.

## Weryfikacja

- Pięć istniejących testów UI przeszło w przebiegach `.build/Glass-final-check-iOS17.xcresult` na iOS 17.5 i `.build/Glass-final-iOS26.xcresult` na iOS 26.5. Scenariusz przeniesienia życzenia sprawdza teraz zapis noszenia z ekranu szczegółów, dezaktywację obu akcji i zachowanie wpisu po restarcie. Są to przebiegi wcześniejsze niż `Free-delivery-iOS17.xcresult` opisany w dokumencie weryfikacji FREE.
- Raporty: `.build/Glass-iOS17.xcresult` i `.build/Glass-isolated-iOS26.xcresult`. Pierwszy przebieg iOS 26 na współdzielonym symulatorze zakłócała inna aplikacja; końcowy pełny przebieg wykonano na osobnym symulatorze „MojeZegarki Glass QA”.
- Oględziny PL: systemowa nawigacja, ekran ze zdjęciem, zapis i potwierdzenie noszenia, tryb jasny i ciemny. Największy Dynamic Type ze zwiększonym kontrastem ujawnił skracanie etykiety; poprawiono układ i potwierdzono pełne dwuwierszowe wyświetlanie.
- Po poprawce typografii i kontrastu scenariusz zapisu przeszedł ponownie na obu systemach: `.build/Glass-final-iOS26.xcresult` i `.build/Glass-final-check-iOS17.xcresult`. Pierwsza końcowa próba na iOS 17 zatrzymała się na kroku Anuluj, jeszcze przed ekranem noszenia; ponowny przebieg bez zmiany kodu przeszedł. Po powtórzeniu problemu przycisk anulowania otrzymał stabilny identyfikator dostępności używany przez test UI.
- Zrzuty wykorzystują syntetyczną ilustrację testową: [kolekcja](assets/liquid-glass/collection26-pl.png), [szczegóły — jasny](assets/liquid-glass/detail26-pl.png), [szczegóły — ciemny](assets/liquid-glass/detail26-dark-pl.png), [największy tekst i kontrast](assets/liquid-glass/detail26-accessibility.png), [potwierdzenie](assets/liquid-glass/confirmation26-pl.png).
- Kontrola fizycznego urządzenia, VoiceOver i systemowego ograniczania przezroczystości/ruchu pozostaje do wykonania; obsługa tych preferencji jest w kodzie. Zmiana nie obejmuje pełnego audytu dostępności pozostałych ekranów.

## Źródła

- [Apple — Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple — Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Apple — Glass prominent button style](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent)
