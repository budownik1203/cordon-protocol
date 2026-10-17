# Protokół: Kordon

Taktyczna gra extraction w widoku z góry (PvE, Godot 4, pixel art). Szczegóły projektu są w dokumencie GDD.

## Uruchomienie
1. Zainstaluj Godot 4.4 (standardowa wersja, nie .NET).
2. W Godot: Import → wskaż plik `project.godot` → Otwórz.
3. Naciśnij F5 (uruchom projekt).

## Sterowanie (prototyp 2)
- WASD: ruch
- Mysz: celowanie, LPM: strzał
- R: przeładowanie
- C (przytrzymaj): przykucnięcie (wolniej, mniejszy rozrzut)
- 1 bandaż, 2 hemostatyk, 3 szyna, 4 środek przeciwbólowy (leczenie trwa i spowalnia)
- Enter: restart po śmierci

## Co jest w prototypie 2
- Ciało z 5 częściami, krwawienie, złamanie nogi, ból, hełm i kamizelka (klasa pancerza kontra penetracja).
- Dwóch wrogów: widzą stożkiem 110°, słyszą strzały, łączą się radiem, jeden bierze osłonę i wychyla się, drugi flankuje.
- Żółta kropka nad wrogiem: widzi cię. Pomarańczowa: szuka.

## Struktura
- `scenes/` sceny, `scripts/` kod, `data/` zasoby danych (np. bronie), `autoload/` globalne skrypty, `tests/` testy, `docs/` notatki.

## Testy (bez okna)
Przy pierwszym uruchomieniu z konsoli wykonaj `godot --headless --path . --import`.
- `godot --headless --path . --script res://tests/smoke.gd`
- `godot --headless --fixed-fps 60 --path . --script res://tests/ai_test.gd`
- `godot --headless --path . --script res://tests/body_test.gd`
(Komunikaty o nieznanym `Events` przy starcie testów można zignorować, to autoload.)
