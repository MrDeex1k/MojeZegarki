# Moje Zegarki — dokumentacja projektu

Aplikacja na iPhone’a do prywatnego zarządzania kolekcją zegarków. Pierwszy własny projekt właściciela, który pracuje już ze Swiftem; cel: własny użytek i publikacja w App Store.

## Aktualny status

Stan implementacji: 2026-09-08. Repozytorium zawiera lokalny zakres funkcjonalny FREE: kolekcję, zdjęcia, Archiwum, noszenie, listę życzeń, dokumenty oraz blokadę dostępu. Do publikacji pozostają weryfikacja fizycznych urządzeń i przygotowanie dystrybucji. Szczegóły uruchomienia znajdują się w [głównym README](../README.md), a dowody i ograniczenia w [raporcie FREE](10-free-weryfikacja.md).

## Zatwierdzony kierunek

- Pierwsza platforma: iPhone; języki PL i EN.
- SwiftUI i lokalna baza SwiftData; minimalny system iOS 17.0.
- FREE: kolekcja, archiwum, zdjęcia, dane zakupu i dokumenty, noszenie i historia, lista życzeń, opcjonalna blokada dostępu.
- Brak limitów ilościowych zegarków, zdjęć i dokumentów.
- Zdjęcia HEIC z JPEG jako formatem zapasowym; pojedynczy dokument maksymalnie 20 MB.
- Brak ręcznego eksportu i importu kolekcji w FREE.
- Pierwsza publikacja obejmuje FREE, bez paywalla i bez synchronizacji.
- Późniejsze Premium: wyłącznie synchronizacja iCloud, subskrypcja miesięczna.
- Bez własnego backendu, reklam i zewnętrznej analityki w pierwszej wersji.

## Spis treści

- [Wizja produktu](./01-wizja-produktu.md)
- [Zakres MVP](./02-zakres-mvp.md)
- [Architektura](./03-architektura.md)
- [Model danych](./04-model-danych.md)
- [Monetyzacja](./05-monetyzacja.md)
- [Prywatność i bezpieczeństwo](./06-prywatnosc-i-bezpieczenstwo.md)
- [Roadmapa](./07-roadmapa.md)
- [Decyzje, ryzyka i pytania otwarte](./08-decyzje-ryzyka.md)
- [Etap 1 — weryfikacja historyczna](./09-etap-1-weryfikacja.md)
- [FREE — weryfikacja i następne kroki](./10-free-weryfikacja.md)

## Źródła techniczne

- [SwiftData — wprowadzenie i wymaganie iOS 17](https://developer.apple.com/videos/play/wwdc2024/10137/)
- [Konfiguracja synchronizacji SwiftData](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct/automatic)
- [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Formaty odczytu i zapisu Image I/O](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/ImageIOGuide/imageio_basics/ikpg_basics.html)
- [Enkoder WebP — libwebp](https://developers.google.com/speed/webp/docs/api)
