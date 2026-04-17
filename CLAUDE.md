LESE DIe README.md und die roadmap.md

IMMER EXPLIZIT FRAGEN BEVOR ÄNDERUNGEN GEMACHT WERDEN

Die implememtierung immer wieder durch rpckfragen bestätigen lassen;

SO EINFACH WIE MÖGLICH;

IMMER die einfachste Lösung nehmen. Wenn etwas Komplexes nötig erscheint, vorher Rücksprache halten.

Keine fancy Language-Features. Kein Singleton-Pattern, keine Overload-Ketten, kein Option wo ein einfacher Wert reicht.
Indices statt IDs. Direkte seq-Zugriffe statt Lookup-Funktionen.
Value-Types (object) statt ref object wo möglich.
Alle Types leben in types.nim.

Code mit `block SEMANTIC_NAME:` in semantische Blöcke strukturieren.
Weniger Funktionen, mehr Inlining. Nur Funktionen wenn: Code mehrfach verwendet wird oder Nims Modulstruktur es erfordert.