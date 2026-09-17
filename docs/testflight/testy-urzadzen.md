# Testy fizycznych urządzeń — 0.8.0

Systemy podane przez właściciela; nie są wynikami testów. Początkowo trzech testerów, docelowo do 15–20. Nie zapisujemy tu prywatnych danych testerów.

| Telefon | iOS | Instalacja TestFlight | Wynik scenariuszy |
| --- | --- | --- | --- |
| iPhone 15 Pro — właściciel | 27.0 | Do wykonania | Do wykonania |
| iPhone 12 | 26.6 | Do wykonania | Do wykonania |
| iPhone 17 | 26.6 | Do wykonania | Do wykonania |

Przy każdym przebiegu zapisać numer buildu, dokładną wersję iOS i datę. Lista urządzeń nie potwierdza działania na minimalnym iOS 17; wcześniejsze wyniki symulatorów pozostają w [raporcie FREE](../10-free-weryfikacja.md).

## Scenariusze do zaliczenia na każdym telefonie

- [ ] Instalacja, pierwsze uruchomienie i ponowny start.
- [ ] Dodanie zegarka i kilku zdjęć, wybór zdjęcia głównego, edycja, wyszukiwanie.
- [ ] Zachowanie danych po zamknięciu i ponownym uruchomieniu aplikacji.
- [ ] Oznaczanie dzisiejszego i wcześniejszego dnia; brak duplikatu zegarek/dzień.
- [ ] Lista życzeń: edycja, anulowanie i zatwierdzenie przeniesienia do kolekcji.
- [ ] PDF i zdjęcie dokumentu: import z faktycznie używanego dostawcy Plików/Zdjęć, podgląd, edycja, usuwanie.
- [ ] Face ID i kod urządzenia: sukces, anulowanie, powrót z tła, ukryta kolekcja w przełączniku aplikacji.
- [ ] Tryb samolotowy; zapis i podgląd lokalnych danych bez sieci.
- [ ] Jasny i ciemny motyw; PL/EN; największy tekst; podstawowe przejście z VoiceOver.
- [ ] Archiwizacja, przywracanie i trwałe usuwanie danych demonstracyjnych.
- [ ] Większe zdjęcia i dokumenty, plik przekraczający limit 20 MB oraz mała ilość wolnego miejsca, jeśli można bezpiecznie odtworzyć taki stan.
- [ ] Aktualizacja do kolejnego buildu TestFlight zachowuje kolekcję — do sprawdzenia po udostępnieniu buildu 2.

Wynik dla każdego scenariusza: PASS / FAIL / NIE SPRAWDZONO. Do błędu dołączyć kroki, oczekiwany i rzeczywisty rezultat, model, iOS, wersję/build; używać danych testowych i usuwać prywatne informacje ze screenów. Feedback: TestFlight lub mywatches@mail.batycki.dev.
