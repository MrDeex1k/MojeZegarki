# Pilotaż e2e i Flashwrighta

`e2e` sprawdza natywną aplikację na symulatorze iOS. Flashwright sprawdza obsługę formularza w Chromium na przykładowej stronie dostarczanej z testu. Obecna regresja aplikacji jest dostępna przez `scripts/test-ios.sh` i plan Xcode `Regression`.

## Uruchomienie

Wymagany jest Node.js 22.22.3 lub nowszy w linii 22, albo 24.8 lub nowszy. Polecenia uruchamiaj z katalogu głównego repozytorium.

```sh
npm --prefix e2e ci
```

### Natywny iOS

Na macOS z Xcode 27 lub nowszym i zainstalowanym runtime iOS podaj UUID wybranego symulatora.

```sh
IOS_DESTINATION='<UUID symulatora>' npm --prefix e2e run test:ios
```

Skrypt buduje i instaluje wariant Debug z identyfikatorem `pl.jakubbatycki.MojeZegarki.E2EPilot`. Ten wariant ma własny kontener. Każdy scenariusz startuje z pustą bazą testową. Restart w środku scenariusza zachowuje zapisane dane. Scenariusze używają jawnych selektorów i asercji, a skrypt wyłącza telemetrię e2e. Raport jest w `e2e/.e2e/report.json`, a artefakty awarii w `e2e/.e2e/results/`.

Skrypt w razie potrzeby uruchamia wybrany symulator i czeka na jego gotowość przed instalacją aplikacji. Pilotaż przechowuje stan sterownika `agent-device` w `.build/e2e-driver/`. Uruchamiaj go na symulatorze wolnym od innych sesji automatyzacji.

### Chromium

```sh
npm --prefix e2e run install:web
npm --prefix e2e run test:web
```

Test uruchamia formularz zwracany przez fixture testu, bez uruchamiania serwera aplikacji. Alias npm dostarcza Flashwrighta pod nazwą `@playwright/test`. Konfiguracja używa ścisłej izolacji kontekstów i zapisuje ślad po awarii w `e2e/test-results/`.

## Plan wdrożenia

1. Zmierzyć stabilność obu scenariuszy iOS na tym samym symulatorze, uruchamiając każdy 10 razy bez retry. Sprawdzić raport po celowo wywołanym błędzie. Po spełnieniu tych warunków dodać osobny job e2e obok regresji Xcode na runnerze macOS z odpowiednim Xcode i runtime iOS.
2. Ustalić, czy istnieją używane poza repozytorium scenariusze Maestro. Jeśli są, przenosić je pojedynczo po porównaniu wyniku i diagnostyki. Audyt dostępności i testy zależne od fizycznego urządzenia nadal wykonywać w Xcode.
3. Ustalić, gdzie działa obecny workflow Playwrighta. Przed podmianą pakietu lub konfiguracji MCP porównać ten sam rzeczywisty scenariusz w obu narzędziach. Kryteria przełączenia to zgodność wyników i artefaktów oraz mierzalna korzyść na tym samym środowisku. W razie regresji można przywrócić wcześniejszy pakiet z lockfile’em lub wpis MCP.
