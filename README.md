# Protokół: Kordon (prototyp 4)

PvE top-down taktyczna gra extraction (Godot 4.4, GDScript, pixel art 640x360).

## Uruchomienie
Godot 4.4 → Import → `project.godot` → F5. Pierwsze uruchomienie: kontrakt → szkolenie.

## Sterowanie
WASD ruch · mysz celowanie/strzał · LPM strzał · R przeładowanie · Tab ekwipunek · E interakcja/loot · M mapa · Shift cicho/Ctrl skradanie (wg ustawień Inputs)

## Zawartość
- Baza: 3 handlarzy (Zbrojmistrz, Medyk, Skup) z dialogami, questy (3 na handlarza, wybór nagrody), ubezpieczenia, poczta
- Biomy: Poligon szkoleniowy, Przedmieścia, Kompleks badawczy (odblokowanie po ewakuacji z Przedmieść)
- Rajd: generowane mapy, frakcje, fauna, elita z kluczem ewakuacji, pokój anomalii, mgła wojny + mapa
- Śmierć: ubezpieczone przedmioty wracają pocztą, reszta w zwłokach do odzyskania w następnym rajdzie
- Grafika i dźwięk generowane proceduralnie: `tools/gen_art.py`, `tools/gen_audio.py`

## Testy
`tools/gd.sh tests/<nazwa>.gd <timeout> [args]` (wymaga zmiennej GODOT).

## Braki
Biomy 4–8, bossowie, modyfikacje broni/crafting. Dźwięki nie były odsłuchane przez autora kodu.
