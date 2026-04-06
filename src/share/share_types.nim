import std/random

type 
    TileId* =  int
    UnitId* =  int
    ChunkId* =  int
    FactionId* =  int

    TileKind* = enum
        Grass

    ZoomLevel* = enum
        VERY_CLOSE, CLOSE, DEFAULT, FAR, VERY_FAR

proc getUniqueId(): int = rand(int.high)
proc newUnitId*(): UnitId = UnitId(getUniqueId())
proc newChunkId*(): ChunkId = ChunkId(getUniqueId())
proc newFactionId*(): FactionId = FactionId(getUniqueId())
