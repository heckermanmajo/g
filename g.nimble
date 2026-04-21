import std/tables

# Package
version       = "0.1.0"
author        = "mo"
description   = "Chunk-based real-time strategy game with raylib"
license       = "Proprietary"
srcDir        = "src"
bin           = @["game/main", "mapeditor/main"]
namedBin      = {"game/main": "game", "mapeditor/main": "mapeditor"}.toTable()

# Dependencies
requires "nim >= 2.2.8"
requires "naylib >= 24.0"
