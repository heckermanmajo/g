# MVP — Features bis zur spielbaren Schlacht

Ziel: Eine abschließbare Schlacht mit klarem Sieg/Niederlage, taktischem Kern und AI-Gegner. Nur die Mechaniken, die für diesen Loop nötig sind. Alles andere ist Post-MVP (siehe `roadmap.md`).

## Bereits implementiert
- Units bewegen, selektieren, kommandieren (Pathfinding Chunk-zu-Chunk)
- Kamera, Zoom, Map mit Chunks/Tiles
- Schießen, Geschosse, Explosionen, Schaden
- Kraft als Ressource, Spawn-Queue, Truppen-Definitionen (INI)
- Spawn-Chunks am Kartenrand
- AI-Grundgerüst mit Strategien

## Noch offen für MVP

### Chunk-Eroberung
- Chunk gehört der Fraktion, die Units darauf hat (keine Gegner anwesend)
- Mehrere Fraktionen auf einem Chunk = umkämpft, gehört niemandem
- Kein Capture-Balken, kein Timer — reine Präsenz entscheidet

### Kraft-Bonus-Chunks
- Manche Chunks geben einmalig Kraft bei Eroberung
- Manche Chunks geben fortlaufend Kraft solange man sie hält
- Welche Chunks Boni geben, wird pro Map festgelegt

### Bunker
- Feste Gebäude auf der Map, platziert auf Chunks
- Units können Bunker besetzen (schützen die Units drinnen)
- Bunker können zerstört werden
- Platzierung so, dass Pathfinding simpel bleibt (man kann drumrum)

### Siegbedingung
- Verteidiger muss Spawn-Chunks halten
- Angreifer muss Spawn-Chunks des Gegners erobern
- Verliert eine Fraktion alle Spawn-Chunks → Niederlage
- Welche Chunks siegrelevant sind, wird pro Map festgelegt

## Bewusst ausgelassen (Post-MVP)
Siehe `roadmap.md` für die vollständige Feature-Liste. Nicht im MVP:
- Moral-System
- Granaten, Special Ammo (Gas, Flamme, Granatwerfer)
- Tech-Level, Logistik-Chunks
- Out-of-Map-Support (Artillerie, Flugzeuge, Fallschirm)
- Kampagnenkarte, Karteneditor, Zivilisationen
- Sound, Fog of War, Wasserlandungen, Unit-Übernahme
- Schlachtfeld-Effekte über das hinaus was schon drin ist
