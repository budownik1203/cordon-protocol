# Protokół: Kordon

Taktyczna gra extraction w widoku z góry (PvE, Godot 4, pixel art). Szczegóły projektu są w dokumencie GDD.

## Uruchomienie
1. Zainstaluj Godot 4.4 (standardowa wersja, nie .NET).
2. W Godot: Import → wskaż plik `project.godot` → Otwórz.
3. Naciśnij F5 (uruchom projekt).

## Sterowanie (prototyp 1)
- WASD: ruch
- Mysz: celowanie, LPM: strzał
- R: przeładowanie
- C (przytrzymaj): przykucnięcie (wolniej, mniejszy rozrzut)

## Struktura
- `scenes/` sceny, `scripts/` kod, `data/` zasoby danych (np. bronie), `autoload/` globalne skrypty, `tests/` testy, `docs/` notatki.

## Test dymny (bez okna)
`godot --headless --path . --script res://tests/smoke.gd`
