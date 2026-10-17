# Protokół: Kordon (prototyp 4)

PvE top-down taktyczna gra extraction (Godot 4.4, GDScript, pixel art 640x360).

## Uruchomienie
Godot 4.4 → Import → `project.godot` → F5. Pierwsze uruchomienie: kontrakt → szkolenie.

## Sterowanie
WASD ruch · mysz celowanie/strzał · R wymiana magazynka · V pakowanie luźnej amunicji do magazynków · Tab ekwipunek · E interakcja/loot · M mapa · Shift sprint · C skradanie · Q zmiana broni · 1-4 leczenie

## Zawartość
- Baza: 3 handlarzy (Zbrojmistrz, Medyk, Skup) z dialogami, questy (3 na handlarza, wybór nagrody), ubezpieczenia, poczta
- Biomy: Poligon szkoleniowy, Przedmieścia, Kompleks badawczy (odblokowanie po ewakuacji z Przedmieść)
- Rajd: generowane mapy, frakcje, fauna, elita z kluczem ewakuacji, pokój anomalii, mgła wojny + mapa
- Śmierć: ubezpieczone przedmioty wracają pocztą, reszta w zwłokach do odzyskania w następnym rajdzie
- Grafika i dźwięk generowane proceduralnie: `tools/gen_art.py`, `tools/gen_audio.py`

## Magazynki
- Magazynek to przedmiot z nabojami (`loaded`); broń ma włożony magazynek (`Item.mag`).
- R: wymiana na najpełniejszy zapasowy (taktyczna szybciej niż po opróżnieniu; z plecaka +1 s). Bez naładowanych zapasów R dobija naboje z luźnej amunicji jeden po jednym.
- V (albo przycisk w ekwipunku): pakuje luźną amunicję do magazynków, z animacją. W ekwipunku można też przeciągnąć stos amunicji na magazynek.
- Magazynek na broń w slocie: wymiana. Shift+PPM na broni w slocie: wyjmij magazynek. Shift+LPM: połowa stosu. Przyciski: Sortuj, Weź wszystko.
- Na starcie rajdu sprzęt jest przygotowany (magazynki napełnione, magazynek w broni).

## Testy
`tools/gd.sh tests/<nazwa>.gd <timeout> [args]` (wymaga zmiennej GODOT).

## Braki
Biomy 4–8, bossowie, modyfikacje broni/crafting. Dźwięki nie były odsłuchane przez autora kodu.
