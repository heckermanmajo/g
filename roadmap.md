
Sudden Strike 1 + 2 meets Total war; aber in langsam (leicht zu spielen) und mit excalidraw-grafik.

# Stil & PX
- langsam und visuell ansprechend, so dass manw as zu tun hat, aber nicht in
  stress gerät, sondern sich öfter zurück lehnen kann um zuzuschauen
- große Entfernungen: Motorisiertes Gerät ist wichitg
- Kampangenkarte und RealTimeBattles sollen jeweils auch für sich genommen spaß machen
- artillerie soll wirklich lange reichweite haben
- Erstmal kein Fog of War — kommt eventuell später
- wichtig, dass das Kämpfen sich sehr gut anfühlt;: effekte, zerstörung, usw.

## Kamera & Darstellung
- 2D Top-Down
- Units sind Kreise mit etwas mehr Detail, Panzer sind Vierecke
- Schematisch mit etwas Stil in Excalidraw gemacht
- Die Reduktion der möglichen Formen und Designs ermöglicht einen kohärenten, einmaligen Stil
- UI minimal, nicht zu extensiv

## Skalierung
- Eher viele Units pro Seite: 200–500 Units pro Seite

# Features

## Kampfsystem
- Entsteht iterativ mit der Zeit
- Das Schießen & Explosionen-System deckt bereits einiges ab

## Verbündete Fraktionen (teams auf der karte, bis zu 8 spieler, 7 ais)
- Nur Singleplayer: 1 menschlicher Spieler, bis zu 7 AIs

## Kraft
- Kraft ist die einzige Ressource — statischer Startwert pro Schlacht
- Manche Chunks geben einmalig Kraft bei Eroberung
- Manche Chunks geben fortlaufend Kraft solange man sie hält
- Truppen und Out-of-Map-Support kosten Kraft
- Balancing der konkreten Werte kommt später

## AI-Strategien
- AI arbeitet chunk-basiert
- AI will relevante Chunks erobern und verteidigen (Bonus-Chunks, strategische Positionen)
- AI versucht eine einheitliche Frontlinie aufrechtzuerhalten
- Für Angriffe konzentriert die AI mehrere Einheiten in einem Chunk bevor sie vorstößt

## Tech-Level
- 3 Tech-Level-Stufen (1–3)
- Höheres Tech-Level schaltet bessere Einheiten und Support frei
- Tech-Level wird pro Schlacht festgelegt (später durch Kampagnenkarte bestimmt)
- Bestimmte Chunks auf der Map können das Tech-Level verbessern wenn erobert
- Details zu was pro Stufe freigeschaltet wird kommen später mit dem Balancing

## Mehrere Fraktionen

## Moral
- Jede Unit/Chunk hat Moral, Basiswert ist 100
- Moral sinkt durch Verluste im Chunk
- Verluste kühlen mit 5 Punkten pro Sekunde ab
- Wenn Moral unter einen Schwellwert fällt, fliehen die Units aus dem Chunk
- Schwellwerte und genaues Balancing kommen später

## Siegbedingungen
- Chunk-basierte Siegbedingungen, abhängig von der jeweiligen Map
- Verteidiger muss seinen Spawn-Punkt und andere wichtige Punkte auf der Map halten
- Angreifer muss diese Punkte erobern
- Welche Chunks siegrelevant sind, wird pro Map festgelegt

## Karteneditor (später)

## Mächtige Units übernehmen (später)
- Spieler kann Kontrolle über einzelne Units übernehmen und diese direkt steuern

## Chunk-Eroberung
- Ein Chunk gehört der Fraktion, die Units darauf hat, solange keine gegnerischen Units auf dem Chunk sind
- Sind Units mehrerer Fraktionen auf einem Chunk, gilt er als "umkämpft" und gehört niemandem
- Kein Capture-Balken, kein Timer — reine Präsenz entscheidet
- Sobald nur noch eine Fraktion Units auf dem Chunk hat, geht er an diese über

## Chunks die man erobern muss
manche chunks auf der karte geben kraft boost wenn man sie erobvert
manche verbessern/verschlechtern logisitik
manche verbessern tech level
manche verbessern moral

## Zivilisationen (später)
- Unterschiedliche Zivilisationen
- Andere Units, Techs, Boni und Siegbedingungen

## Gebäude
- Erstmal nur "Bunker" als Gebäudetyp
- Feste Gebäude auf der Map die man besetzen oder zerstören kann
- Immer so platziert auf einem Chunk, dass man drumrum kann (Pathfinding bleibt simpel)
- Gebäude schützen die Units drinnen
- LKWs können leichte Bunker (Sandsäcke etc.) einmalig platzieren

## Logistik
- Logistik bestimmt die Spawn-Rate (wie schnell neue Truppen aufs Schlachtfeld kommen)
- Bestimmte Chunks auf der Map können die Logistik verbessern oder verschlechtern wenn erobert
- Details zum Balancing kommen später

## Spawn-Chunks
- Bestimmte Chunks am Rand der Map sind Spawn-Punkte
- Dort kommen neue Truppen aufs Schlachtfeld
- Diese Chunks sind die Basislager und müssen verteidigt werden

## Stationäre Geschütze
- Können auf der Map platziert oder erobert werden
- Brauchen Bediener (Soldaten)
- Ein LKW kann ein Geschütz ziehen und dann abladen (wie bei Sudden Strike)
- LKWs können auch einmalig leichte Bunker (Sandsäcke) platzieren

## Panzer
- langsame farhzeige moit großer feuerkraft

## Special Ammo Vehicles
- artillierie  (pamnzer und default)
- giftgasgranten
- flammenwerfer
- Granatwerfer

## Geschütze (beweglich)
- Stationäre Geschütze können auch ohne LKW von Hand geschoben werden
- Sehr viel langsamer als mit LKW (wie bei Sudden Strike)

## Leichte Fahrzeuge
- Aufklärung
- unterstützen von Infantrie
- schnelle stoßtruppen/elitetruppen liefern und supporten um wichitge punkte einzunehmen

## Transporter
Können truppen und Besondere Munition transportieren.
viele fahrzeuge können truppen transportieren

## Berg-Chunks; Wasser-CHunks
- hier kann man nicht lang, sie machen die maps interessant

## Schadens-System
- Drei Schadenskategorien: Leicht, Mittel, Schwer
- Leichte Waffen treffen nur leichte Ziele
- Mittlere Waffen treffen leichte und mittlere Ziele
- Schwere Waffen treffen alle Ziele (leicht, mittel, schwer)
- Jede Einheit gehört einer Kategorie an (z.B. Infantrie = leicht, Panzer = schwer)
- Zusätzlich: Panzerung in % — absorbiert entsprechenden Anteil des Schadens
- Jede Einheit hat 100 Lebenspunkte
- Explosionen haben 3 Radien: einen schweren (innen), einen mittleren, einen leichten (außen)
- Balancing kommt später

## Schießen & Explosionen (eigenes System)
- Units schießen nicht 100% perfekt — Abweichung basiert auf Qualität und Bewaffnung der Einheit
- Die Engine berechnet das automatisch
- Explosionen sollen sich anfühlen wie Sudden Strike 1 & 2
- Deckt ab: direkte Schüsse, Geschosse, Explosionen, Granaten

## Geschosse
- raketen, granaten, panzergeschosse fliegen über die map als objekte

## Raketen

## Out-of-Map-Support
- Artillerie, Raketen, Flugzeuge, Fallschirmspringer können von außerhalb der Map gerufen werden
- Kostet Kraft
- Verfügbarkeit hängt vom Tech-Level ab (höheres Tech-Level = mehr/besserer Support)
- Flugzeuge: Schatten fliegen über das Schlachtfeld, dann fallen Bomben/Raketen
- Fallschirmspringer: Können überall auf der Map landen (nicht nur Spawn-Chunks)

## Spawning
- man kann units nur über die logisitik-chusnk am rand holen
- außer fallschirmspringer/fallschirm fahrzeuge

## Truppen-Definitionen
- Truppentypen werden als einzelne INI-Dateien definiert und zur Laufzeit eingelesen
- Jede INI-Datei beschreibt einen Truppentyp (Name, Kategorie, Lebenspunkte, Panzerung, Waffe, Kosten, etc.)
- Units werden zu Truppen zusammengefasst (z.B. 50 Soldaten auf LKWs = eine motorisierte Infantrie-Truppe)
- Man ruft Truppen als Ganzes ins Schlachtfeld, nicht einzelne Units
- Grafiken werden als einzelne PNGs bereitgestellt und den Truppentypen zugeordnet
- Ermöglicht einfaches Modding und Balancing ohne Code-Änderungen

## Spawn-Queue & Truppen
- Sichtbare Spawn-Queue für den Spieler
- Spieler kann Truppen in Spawn-Chunks am Rand der Map rufen
- Truppen haben Tech-Level und kosten unterschiedlich viel Kraft
- Lower-Tier Infantrie hat weniger Moral, weniger Technik, weniger Erfahrung, z.B. ohne Granaten

## Wasserlandungen (später)
- Wie an einem Strand

## Schlachtfeld-Effekte (Immersion, kein Gameplay-Effekt)
- Kein Gameplay-Effekt, aber persistent auf dem Schlachtfeld
- Feuer (Timer, verschwindet nach einer Weile)
- Rauch (Timer, verschwindet nach einer Weile)
- Schrott (wenn ein Panzer zerstört wird)
- Leichen, Leichenteile
- Blut

## Strategischer Mode bei Zoom out
- Ab Zoom-Stufe VERY_FAR schaltet der strategische Mode ein
- Unit-Details werden durch einfache Kreise und Vierecke ersetzt
- Tiles werden nicht mehr gezeichnet, Feuer und Rauch weggenommen
- Man kann trotzdem kommandieren
- Selbe Map, nur mit weniger Details

## Granaten
- Können von Units mit eigener Entscheidung geworfen werden
- Fliegen über die Map, landen, Timer läuft ab, dann Explosion mit Radius
- Unterschiedliche Granatentypen, z.B. Anti-Tank-Granaten die nur gegen Panzer eingesetzt werden
- Siehe Explosionen

## pathfinding
- make simple units walk from chunk to chunk
- chunk to chunk astar
- spawn chunks

## Sound (später)
- Sprache selbst aufnehmen oder AI
- Musik/Soundtrack mit AI
- Erstmal nicht relevant



- excalidraw-based ahstetics
- Simple Units
- Simples Kampf-System
    - wie kann man ein simples kampfsystem modellieren
    - unit behaviour > chat gpt konversation mit labern
- simples resourcen system: eine zahl: Kraft

- einige chunks geben gewisse boni; 
    - schnellerer spawn
    - mehr units auf der map
    - mehr moral
- man hat eine spawn-qeue
- man schickt units von start-chunks in die map hinein
- luft und artillerie schläge und sachen von außerhalb der map rein callen

---

# Phasen

## Phase 1 — Grundgerüst (abgeschlossen)
- Engine mit Raylib, Game-Loop, Debug-Overlay
- Chunk-basierte Map mit Tiles, Kamera, Zoom, Tile-Selection
- Fraktionen-Grundgerüst (2 Fraktionen, Kraft-Ressource)
- Gras-Texturen rendern

## Phase 2 — Gameplay-Kern

### Phase 2.1 — Units bewegen sich
- [ ] Units auf der Map platzieren (Position, Chunk-Zugehörigkeit)
- [ ] Units einer Fraktion zuordnen
- [ ] Einfaches Pathfinding (Chunk-zu-Chunk A*)
- [ ] Units per Rechtsklick zu einem Ziel-Chunk schicken
- [ ] Units als Kreise (Soldaten) / Vierecke (Panzer) zeichnen

### Phase 2.2 — Kampfsystem Grundlagen
- [ ] Units schießen auf feindliche Units in Reichweite
- [ ] Schadens-System (Leicht/Mittel/Schwer Kategorien)
- [ ] Geschosse fliegen als Objekte über die Map
- [ ] Explosionen mit Radien
- [ ] Units sterben bei 0 HP

### Phase 2.3 — Chunk-Besitz & Spawning
- [ ] Chunk-Eroberung durch Präsenz
- [ ] Spawn-Chunks am Kartenrand
- [ ] Spawn-Queue: Truppen rufen kostet Kraft
- [ ] Truppen-Definitionen aus INI-Dateien laden

### Phase 2.4 — Schlachtfeld-Effekte & Feedback
- [ ] Feuer, Rauch (mit Timer)
- [ ] Schrott, Leichen (persistent)
- [ ] Explosion-Effekte die sich gut anfühlen
- [ ] Strategischer Mode bei Zoom-Out (vereinfachte Darstellung)

### Phase 2.5 — Einfache AI
- [ ] AI steuert gegnerische Fraktion
- [ ] AI schickt Units zu relevanten Chunks
- [ ] AI versucht Frontlinie zu halten
- [ ] AI sammelt Units bevor sie angreift

# Kampagnenkarte (später)
- Grid-System mit Armeen und Logistik-Zentren
- Armeen haben: Kraft, Tech-Level, Training
- Eine Armee kann nur einen Schritt pro Runde gehen
- Penalties für Armeen die zu weit von Logistik-Zentren entfernt sind
- Keine Chunks auf der Kampagnenkarte
- Zivilisations-Editor (wie Karteneditor, auf später verschoben)
