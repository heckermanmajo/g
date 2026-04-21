import std/os
import std/random
import std/strutils
import std/streams

import types

const MAPS_DIR* = "maps"

proc tileKindForChunk*(k: ChunkKind): TileKind =
    case k
    of ChunkKind.Grass: TileKind.Grass
    of ChunkKind.Mountain: TileKind.Mountain
    of ChunkKind.Water: TileKind.Water
    of ChunkKind.Spawn: TileKind.Spawn

proc buildTilesForChunk*(chunk: var Chunk, chunkSizeInTiles: int) =
    let tk = tileKindForChunk(chunk.kind)
    chunk.tiles = @[]
    for tileX in 0 ..< chunkSizeInTiles:
        for tileY in 0 ..< chunkSizeInTiles:
            let textureKey = if tk in {TileKind.Grass, TileKind.Spawn}: "gras" & $(rand(1..6))
                             else: ""
            chunk.tiles.add(Tile(
                x: chunk.x + tileX * PIXELS_PER_TILE,
                y: chunk.y + tileY * PIXELS_PER_TILE,
                passable: chunk.passable,
                kind: tk,
                textureKey: textureKey
            ))

proc newEmptyMap*(sizeInChunks: int, chunkSizeInTiles: int, generateTiles: bool = true): Map =
    result.mapSizeInChunks = sizeInChunks
    result.chunkSizeInTiles = chunkSizeInTiles
    result.chunkSizePixels = chunkSizeInTiles * PIXELS_PER_TILE
    result.mapSizePixels = sizeInChunks * result.chunkSizePixels
    result.chunks = @[]
    for cx in 0 ..< sizeInChunks:
        for cy in 0 ..< sizeInChunks:
            var chunk = Chunk()
            chunk.x = cx * result.chunkSizePixels
            chunk.y = cy * result.chunkSizePixels
            chunk.kind = ChunkKind.Grass
            chunk.passable = true
            chunk.currentOwner = -1
            chunk.spawnForFaction = -1
            chunk.unitIndices = @[]
            chunk.kraftBonusOnCapture = 0
            chunk.kraftBonusClaimed = false
            chunk.kraftPerSecond = 0
            if generateTiles:
                buildTilesForChunk(chunk, chunkSizeInTiles)
            result.chunks.add(chunk)

proc applyChunkKind*(chunk: var Chunk, kind: ChunkKind) =
    chunk.kind = kind
    chunk.passable = kind notin {ChunkKind.Mountain, ChunkKind.Water}
    if kind != ChunkKind.Spawn:
        chunk.spawnForFaction = -1

proc mapFilePath*(name: string): string =
    MAPS_DIR / (name & ".map")

proc listMaps*(): seq[string] =
    result = @[]
    if not dirExists(MAPS_DIR): return
    for file in walkDir(MAPS_DIR):
        if file.kind == pcFile and file.path.endsWith(".map"):
            let name = splitFile(file.path).name
            result.add(name)

proc saveMap*(map: Map, name: string) =
    if not dirExists(MAPS_DIR):
        createDir(MAPS_DIR)
    let path = mapFilePath(name)
    let s = newFileStream(path, fmWrite)
    s.writeLine("[meta]")
    s.writeLine("name=" & name)
    s.writeLine("sizeInChunks=" & $map.mapSizeInChunks)
    s.writeLine("chunkSizeInTiles=" & $map.chunkSizeInTiles)
    s.writeLine("")
    s.writeLine("[chunks]")
    # format: cx,cy=kind,spawnForFaction,kraftBonusOnCapture,kraftPerSecond
    # Default-Chunks (Grass, kein Spawn, keine Boni) werden weggelassen
    for i in 0 ..< map.chunks.len:
        let c = map.chunks[i]
        let isDefault = c.kind == ChunkKind.Grass and c.spawnForFaction == -1 and
                        c.kraftBonusOnCapture == 0 and c.kraftPerSecond == 0
        if isDefault: continue
        let cx = i div map.mapSizeInChunks
        let cy = i mod map.mapSizeInChunks
        s.writeLine($cx & "," & $cy & "=" & $c.kind & "," & $c.spawnForFaction &
                    "," & $c.kraftBonusOnCapture & "," & $c.kraftPerSecond)
    if map.buildings.len > 0:
        s.writeLine("")
        s.writeLine("[buildings]")
        # format: cx,cy=kind
        for b in map.buildings:
            s.writeLine($b.chunkX & "," & $b.chunkY & "=" & $b.kind)
    s.close()

proc loadMap*(name: string, generateTiles: bool = true): Map =
    let path = mapFilePath(name)
    var sizeInChunks = 0
    var chunkSizeInTiles = 0
    var section = ""
    # Erster Pass: Meta lesen
    for line in lines(path):
        let l = line.strip()
        if l.len == 0 or l.startsWith("#"): continue
        if l.startsWith("[") and l.endsWith("]"):
            section = l[1 ..< l.len - 1]
            continue
        if section == "meta":
            let eq = l.find('=')
            if eq < 0: continue
            let key = l[0 ..< eq].strip()
            let val = l[eq + 1 .. ^1].strip()
            if key == "sizeInChunks": sizeInChunks = val.parseInt
            elif key == "chunkSizeInTiles": chunkSizeInTiles = val.parseInt

    result = newEmptyMap(sizeInChunks, chunkSizeInTiles, generateTiles)
    section = ""
    # Zweiter Pass: Chunks und Buildings anwenden
    for line in lines(path):
        let l = line.strip()
        if l.len == 0 or l.startsWith("#"): continue
        if l.startsWith("[") and l.endsWith("]"):
            section = l[1 ..< l.len - 1]
            continue
        let eq = l.find('=')
        if eq < 0: continue
        let keyStr = l[0 ..< eq].strip()
        let valStr = l[eq + 1 .. ^1].strip()
        if section == "chunks":
            let coords = keyStr.split(",")
            if coords.len != 2: continue
            let cx = coords[0].parseInt
            let cy = coords[1].parseInt
            let parts = valStr.split(",")
            if parts.len != 4: continue
            let idx = cx * sizeInChunks + cy
            var chunk = result.chunks[idx]
            let kind = parseEnum[ChunkKind](parts[0])
            applyChunkKind(chunk, kind)
            let rawFaction = parts[1].parseInt
            # nur 0..3 sind gueltige Fraktions-Slots; alles andere als "kein Spawn" behandeln
            chunk.spawnForFaction = if rawFaction in 0..3: rawFaction else: -1
            chunk.kraftBonusOnCapture = parts[2].parseInt
            chunk.kraftPerSecond = parts[3].parseInt
            if chunk.kind == ChunkKind.Spawn and chunk.spawnForFaction >= 0:
                chunk.currentOwner = chunk.spawnForFaction
            if generateTiles:
                buildTilesForChunk(chunk, chunkSizeInTiles)
            result.chunks[idx] = chunk
        elif section == "buildings":
            let coords = keyStr.split(",")
            if coords.len != 2: continue
            let cx = coords[0].parseInt
            let cy = coords[1].parseInt
            let bk = parseEnum[BuildingKind](valStr)
            result.buildings.add(MapBuilding(kind: bk, chunkX: cx, chunkY: cy))
