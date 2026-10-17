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

## Obrażenia i leczenie (jak w Tarkovie)
- 7 części ciała (głowa 35, klatka 85, brzuch 70, ręce 60, nogi 65 HP). Śmierć: głowa lub klatka na 0.
- Krwawienia (lekkie/ciężkie) i złamania są przypisane do części. Kończyna na 0 HP jest zniszczona, a nadmiar obrażeń rozchodzi się na resztę ciała (bez głowy).
- Bandaż: lekkie krwawienie. Opaska hemostatyczna: ciężkie. Szyna: złamanie. Apteczka: leczy HP wybranej części z zasobu. Zestaw chirurgiczny: przywraca zniszczoną kończynę (z karą do maks. HP). Środek przeciwbólowy działa na całe ciało i łagodzi złamania.
- Leczenie per część: w ekwipunku (Tab) przeciągnij środek na część ludzika albo Shift+PPM na środku (auto). Klawisze 1-9: pasek szybkiego dostępu, cel dobierany automatycznie.
- Pasek do dostosowania: w ekwipunku trzymaj środek i kliknij slot albo najedź na środek i wciśnij 1-9. PPM czyści slot.
- HUD pokazuje tylko ikonkę obrażeń, pasek skrótów i amunicję. Okno 1920x1080 (świat 640x360 w skali x3).
- Ruch: inercja, wolny obrót tułowia (gwałtowny obrót psuje celowanie), rozbieg sprintu, wpływ wagi i nóg.

## Magazynki
- Magazynek to przedmiot z nabojami (`loaded`); broń ma włożony magazynek (`Item.mag`).
- R: wymiana na najpełniejszy zapasowy (taktyczna szybciej niż po opróżnieniu; z plecaka +1 s). Bez naładowanych zapasów R dobija naboje z luźnej amunicji jeden po jednym.
- V (albo przycisk w ekwipunku): pakuje luźną amunicję do magazynków, z animacją. W ekwipunku można też przeciągnąć stos amunicji na magazynek.
- Magazynek na broń w slocie: wymiana. Shift+PPM na broni w slocie: wyjmij magazynek. Shift+LPM: połowa stosu. Przyciski: Sortuj, Weź wszystko.
- Na starcie rajdu sprzęt jest przygotowany (magazynki napełnione, magazynek w broni).

Pełna dokumentacja: `docs/DOKUMENTACJA.md`. F11 = pełny ekran.

## Próba 3D (spike)
Przyciski „Test 3D (z góry)" i „Test FPS" w bazie albo `scenes/proto3d.tscn` / `scenes/protofps.tscn` (F6). Ten sam generator poziomów i model obrażeń, ale świat low poly 3D (kamera z góry pod kątem, latarka z cieniami, wrogowie z AI i pathfindingiem, skrzynie na E, strefy ewakuacji). Postacie i poziom są budowane kodem z sześcianów. WASD, mysz, LPM, R, Shift, C, E, Esc wraca do bazy. To tylko próbka do oceny wyglądu, bez ekwipunku i questów.

## Testy
`tools/gd.sh tests/<nazwa>.gd <timeout> [args]` (wymaga zmiennej GODOT).

## Braki
Biomy 4–8, bossowie, modyfikacje broni/crafting. Dźwięki nie były odsłuchane przez autora kodu.
