# Protokół: Kordon — dokumentacja projektu

Stan: 17.10.2026 · Godot 4.4.1 (GL Compatibility) · GDScript ze statycznym typowaniem · repozytorium `main`

## 1. Wizja
Taktyczna gra PvE typu extraction (struktura Tarkova + losowe pokoje jak w Enter the Gungeon). Gracz przygotowuje wyposażenie w bazie, wchodzi do generowanej strefy kwarantanny, walczy z frakcjami i fauną, zbiera łup i ewakuuje się. Śmierć = utrata tego, co niosłeś, z szansą odzyskania ubezpieczonych rzeczy pocztą i reszty ze zwłok w następnym rajdzie. Ton: surowy, z suchą satyrą (biurokratyczne komunikaty).

Zespół: jeden programista (gracz-twórca) + Claude (kod, dane, testy, dokumentacja). Gracz testuje i decyduje.

## 2. Uruchomienie i sterowanie
Godot 4.4 → Import → `project.godot` → F5. Okno dopasowuje się do ekranu (16:9), **F11** = pełny ekran. Świat 640×360 skalowany ×3 (FHD), `stretch=canvas_items`, `aspect=keep`.

| Klawisz | Akcja |
|---|---|
| WASD | ruch (inercja, ciężki chód) |
| Mysz / LPM | celowanie / strzał |
| R | wymiana magazynka (przeładowanie) |
| V | pakowanie luźnej amunicji do magazynków |
| Tab | ekwipunek |
| E | interakcja / loot |
| M | mapa |
| Shift / C | sprint / skradanie |
| Q | zmiana broni |
| 1–9 | pasek szybkiego dostępu (konfigurowalny) |
| F11 | pełny ekran |

## 3. Pętla rozgrywki
Baza (handlarze, skrytka, poczta, wybór kontraktu i biomu) → przygotowanie sprzętu → rajd (generowana mapa, mgła wojny, loot, walka) → ewakuacja albo śmierć → raport z rajdu → baza.

- **Baza:** Zbrojmistrz, Medyk, Skup (łupy). Dialogi, 3 questy na handlarza z wyborem nagrody, ubezpieczenia, poczta.
- **Biomy:** Poligon szkoleniowy (szkolenie), Przedmieścia, Kompleks badawczy (odblokowany po ewakuacji z Przedmieść). Definicje: `data/biomes.gd`.
- **Rajd:** generator poziomów (`scripts/raid/level_gen.gd`), frakcje (Szabrownicy, Najemnicy, Wojskowi), fauna, elita z kluczem ewakuacji, pokój anomalii, mapa z mgłą wojny.
- **Śmierć:** ubezpieczone przedmioty wracają pocztą, reszta zostaje w zwłokach.

## 4. Model obrażeń (jak w Tarkovie) — `scripts/body.gd`
- 7 części ciała: głowa 35, klatka 85, brzuch 70, ręce 60 (każda), nogi 65 (każda) HP.
- Śmierć: głowa lub klatka do 0 HP.
- Krwawienie per część (0 brak / 1 lekkie / 2 ciężkie), złamania per część.
- Kończyna na 0 HP jest **zniszczona**; nadmiar obrażeń (70%) rozchodzi się po częściach poza głową.
- Skutki: prędkość, rozrzut i czas przeładowania zależą od stanu rąk i nóg; sprint możliwy tylko ze sprawnymi nogami i bez złamań.
- Leczenie: bandaż (lekkie krwawienie), opaska hemostatyczna (ciężkie), szyna (złamanie), apteczka (pula HP w `Item.durability`, 60 na użycie, leczy wybraną część), zestaw chirurgiczny (przywraca zniszczoną kończynę: 30% HP, −20% maks. HP części), środek przeciwbólowy (całe ciało, łagodzi złamania).
- Użycie jest czasowe (`Player.start_use`). Cel dobierany automatycznie (`needs()` / `auto_target()`) lub wskazany ręką: w ekwipunku przeciągnij środek na część ludzika.

## 5. Ekwipunek, magazynki, broń
- Siatka przedmiotów (`Bag`), sloty ciała (`Equipment`), przedmioty z wagą i rozmiarem (`Item`, `item_db.gd`).
- **Magazynek jest przedmiotem** (`type:"mag"`, `cap`, `loaded`, jeden typ amunicji). Broń ma włożony magazynek (`Item.mag`).
- **R:** wymiana na najpełniejszy zapasowy — taktyczna szybciej (0.5×), z pustego wolniej (0.8×), z plecaka +1 s. Bez naładowanych zapasów dobijanie naboi po jednym (0.3 s).
- **V:** pakowanie luźnej amunicji (0.09 s/nabój), także przeciągnięciem stosu na magazynek w ekwipunku (animowane).
- Animacje przenoszenia: lecące „duchy” przedmiotów, wygładzony przedmiot w ręce, podświetlenia, sortowanie (`Bag.repack`), „weź wszystko”, Shift+LPM = połowa stosu, Shift+PPM na broni = wyjmij magazynek.
- **Pasek szybkiego dostępu:** 9 slotów, zapisywany; przypisanie przez trzymanie przedmiotu + klik slotu albo najechanie + 1–9; PPM czyści.
- Broń: dane jako zasób (`data/weapon_data.gd`): obrażenia, RPM, rozrzut, odrzut, penetracja 1–6 vs klasa pancerza (`armor_data.gd`), hałas strzału. Trafienia hitscan.
- HUD: ikonka stanu obrażeń, pasek skrótów, amunicja, pasek postępu użycia. Szczegółowy ludzik tylko w ekwipunku.

## 6. Przeciwnicy
`scripts/enemy.gd`, `group_manager.gd`, `grid_nav.gd` (A*, linia wzroku). Frakcje różnią się sprzętem i taktyką; wzrok, słuch (hałas strzałów), stany: bezczynność / walka / poszukiwanie. Fauna w `scripts/raid/fauna.gd`. Wrogowie używają tego samego `Body` co gracz.

## 7. Dane i zapis
Dane w `data/` (biomy, dialogi, questy, broń, pancerze) i `scripts/inv/item_db.gd`. Zapis: `user://save.json` (skrytka, pieniądze, wyposażenie, pasek, odblokowania, statystyki) w `autoload/game.gd`. Autoloady: `Inputs`, `Events`, `Audio`, `Game`.

## 8. Grafika i dźwięk
Pixel art generowany proceduralnie: `tools/gen_art.py`; dźwięk: `tools/gen_audio.py` (dźwięki nie były odsłuchane przez autora kodu — do oceny przez gracza). Grafika w `art/`, audio w `audio/`.

## 9. Próby 3D (spike, poza główną grą)
Przyciski w bazie: **Test 3D (z góry)** i **Test FPS**. Wspólny poziom z generatora, postacie low poly z sześcianów, latarka z cieniami, wrogowie z AI, model obrażeń `Body`.
- Z góry: `scenes/proto3d.tscn`.
- FPS: `scenes/protofps.tscn` — mysz do rozglądania, PPM celowanie (ADS), kołysanie kamery, viewmodel broni, trafienia w część ciała zależnie od wysokości (głowa/klatka/brzuch/ręce/nogi).
Kod: `scripts/proto3d/`. Bez ekwipunku, questów i zapisu. Decyzja o kierunku (2D vs 3D) czeka na ocenę gracza.

## 10. Testy
`tools/gd.sh tests/<nazwa>.gd <timeout> [args]` (zmienna `GODOT` wskazuje binarkę). Zestawy: body, inv, gen, smoke, ai, raid, game, assets, mag, med, world, p3d, pfps oraz bot (4-minutowa symulacja rajdu w obu biomach). Zrzuty: `tests/shot.gd`, `shot3d.gd`, `shotfps.gd` (wymagają Xvfb).
Pułapki: skrypty `SceneTree` nie widzą autoloadów w czasie kompilacji; nowy `class_name` wymaga `--import`.

## 11. Struktura katalogów
`autoload/` singletony · `data/` dane · `scripts/` logika (`inv/`, `raid/`, `ui/`, `proto3d/`) · `scenes/` · `art/`, `audio/` · `tools/` generatory i runner testów · `tests/` · `docs/` dokumentacja.

## 12. Stan i plan
Zrobione: prototypy 1–4 (rajd, baza, handlarze, questy, ubezpieczenia, system ran Tarkov-style, magazynki, hotbar, FHD UI), próby 3D z góry i FPS.
Do zrobienia: biomy 4–8, bossowie, modyfikacje broni i crafting, opcjonalne leczenie po rajdzie u Medyka, odsłuch i dopracowanie audio, decyzja o 2D/3D.
Ryzyka: zakres treści przy jednej osobie; ręczny balans ekonomii; wydajność AI przy wielu grupach.

## 13. Historia zmian (skrót)
- P4: magazynki, animacje przenoszenia, ciężki ruch, FHD, nowy HUD, ludzik w ekwipunku, hotbar, Tarkov-owe rany.
- 3D: próba z góry i FPS low poly.
- Okno dopasowane do ekranu + F11 (poprawka rozjazdu kursora).
