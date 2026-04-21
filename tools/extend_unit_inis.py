#!/usr/bin/env python3
"""Fuegt texturePathGreen und texturePathPurple zu allen Unit-inis hinzu.

Leitet die Pfade schematisch von texturePathRed / texturePathBlue ab, indem
der Farb-Ordner im Pfad getauscht wird (red->purple, blue->green). Idempotent:
laeuft die Datei erneut durch, passiert nichts.
"""
import os
import re

UNIT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "res", "units")


def process(path: str) -> bool:
    with open(path) as f:
        text = f.read()
    if "texturePathGreen" in text and "texturePathPurple" in text:
        return False

    m_red = re.search(r"^texturePathRed=(.+)$", text, re.M)
    m_blue = re.search(r"^texturePathBlue=(.+)$", text, re.M)
    if not m_red or not m_blue:
        return False

    red_path = m_red.group(1).strip()
    blue_path = m_blue.group(1).strip()
    purple_path = red_path.replace("/red/", "/purple/")
    green_path = blue_path.replace("/blue/", "/green/")

    additions = []
    if "texturePathGreen" not in text:
        additions.append(f"texturePathGreen={green_path}")
    if "texturePathPurple" not in text:
        additions.append(f"texturePathPurple={purple_path}")

    # direkt hinter texturePathBlue einfuegen
    insertion = "\n".join(additions)
    new_text = re.sub(
        r"(^texturePathBlue=.+$)",
        r"\1\n" + insertion,
        text,
        count=1,
        flags=re.M,
    )
    with open(path, "w") as f:
        f.write(new_text)
    return True


def main() -> None:
    changed = 0
    for name in os.listdir(UNIT_DIR):
        if not name.endswith(".ini"):
            continue
        path = os.path.join(UNIT_DIR, name)
        if process(path):
            changed += 1
            print(f"  + {name}")
    print(f"{changed} Dateien erweitert")


if __name__ == "__main__":
    main()
