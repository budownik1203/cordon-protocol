# Protokół: Kordon

Taktyczna gra extraction w widoku z góry (PvE, Godot 4, pixel art). Szczegóły projektu są w dokumencie GDD.

## Uruchomienie
1. Zainstaluj Godot 4.4 (standardowa wersja, nie .NET).
2. W Godot: Import → wskaż plik `project.godot` → Importuj i edytuj.
3. Naciśnij F5. Gra startuje w bazie.

## Pętla gry (prototyp 3)
**Baza** (skrytka, ekwipunek, handlarz) → **Wyjście na rajd** → losowy układ pokoi, wrogowie, łup → **ewakuacja** albo śmierć → **raport** → baza.

### Sterowanie w rajdzie
- WASD ruch, Shift sprint, C przykucnięcie, mysz celowanie, LPM strzał
- R przeładowanie, Q zmiana broni (karabin/pistolet)
- E przeszukaj kontener lub ciało, Tab ekwipunek
- 1 bandaż, 2 hemostatyk, 3 szyna, 4 środek przeciwbólowy
- Ewakuacja: stań na zielonej strefie na 6 sekund. Żółta strefa wymaga klucza do bramy kordonu (rzadki łup).

### Ekwipunek (baza i rajd)
- LPM bierze i kładzie przedmiot, R lub PPM obraca trzymany przedmiot, PPM na przedmiocie robi szybką akcję (załóż lub przenieś).
- Każdy pojemnik (plecak, kamizelka, pas, bezpieczny kontener) ma własny układ siatki i redukcję wagi. Plecak Szturmowy: 24 miejsca, -30% wagi. Plecak Kompaktowy: 12 miejsc, -45% wagi.
- Po śmierci przepada wszystko poza bezpiecznym kontenerem. Zestaw startowy w bazie jest darmowy.
- W bazie: kupuj u handlarza (klik), sprzedawaj przez „SPRZEDAJ trzymany" (55% wartości).

### Co działa
- Widok z góry ze stożkiem widzenia 110° i cieniami (wrogowie widoczni tylko, gdy ich widzisz).
- Generator rajdu: graf 8–10 pokoi składanych z ręcznych kawałków, gwarantowana ścieżka do 2 wyjść i 12+ miejsc na łup.
- Ciało z 5 częściami, krwawienie, złamania, ból, pancerz (klasa kontra penetracja amunicji, zużycie).
- Trzy frakcje o różnym sprzęcie i zachowaniu (Szabrownicy, Najemnicy, Wojskowi), cechy charakteru, AI z osłonami, flankowaniem i radiem.
- Fauna (Skażeńcy) pojawia się wraz z licznikiem zagrożenia (czas i hałas).
- Przeszukiwanie odsłania przedmioty stopniowo; ciała wrogów mają łup frakcji.
- Raport po rajdzie z komunikatami zależnymi od przebiegu.
- Zapis w `user://save.json` z kopią zapasową.

### Czego jeszcze nie ma
Ubezpieczenia, odzyskiwania ciała, craftu, wielu biomów i bossów, modyfikacji broni, dźwięku. Grafika to tymczasowe kształty.

## Struktura
- `autoload/` globalne (wejście, zdarzenia, stan gry), `scenes/` sceny, `data/` zasoby danych, `tests/` testy.
- `scripts/inv/` przedmioty, pojemniki, wyposażenie, baza przedmiotów (`item_db.gd` to miejsce na nowe przedmioty).
- `scripts/raid/` generator, łup, fauna, kontroler rajdu. `scripts/ui/` ekwipunek i baza.
- `scenes/main.tscn` to arena testowa z manekinami i dwoma wrogami (uruchom jako scenę przez F6).

## Testy (bez okna)
Przy pierwszym uruchomieniu z konsoli wykonaj `godot --headless --path . --import`.
```
godot --headless --path . --script res://tests/body_test.gd
godot --headless --path . --script res://tests/inv_test.gd
godot --headless --path . --script res://tests/gen_test.gd
godot --headless --path . --script res://tests/smoke.gd
godot --headless --fixed-fps 60 --path . --script res://tests/ai_test.gd
godot --headless --fixed-fps 60 --path . --script res://tests/raid_test.gd
```
Komunikaty o nieznanym `Events` przy starcie testów można zignorować (to autoload).
