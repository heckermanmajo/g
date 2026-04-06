# Phase 3: Spawning & Ressourcen

Truppen aufs Schlachtfeld bringen und Kraft als Ressource verwalten.

## Features

### Kraft
- Einzige Ressource — statischer Startwert pro Schlacht
- Truppen und Out-of-Map-Support kosten Kraft

### Spawn-Chunks
- Bestimmte Chunks am Rand sind Spawn-Punkte
- Dort kommen neue Truppen aufs Schlachtfeld
- Müssen verteidigt werden (Basislager)

### Spawn-Queue
- Sichtbare Spawn-Queue für den Spieler
- Spieler wählt Truppen und ruft sie in Spawn-Chunks

### Truppen-Definitionen
- Truppentypen als INI-Dateien definiert, zur Laufzeit eingelesen
- Name, Kategorie, HP, Panzerung, Waffe, Kosten etc.
- Grafiken als PNGs den Truppentypen zugeordnet
- Units werden zu Truppen zusammengefasst (z.B. 50 Soldaten = eine Truppe)
- Man ruft Truppen als Ganzes, nicht einzelne Units
