import std/options
import std/random

import raylib

import share/share_types
import faction


type

    VisualKind* = enum
        Circle,   ## Soldier: drawn as a circle
        Rect      ## Tank: drawn as a rectangle

    UnitDef* = ref object
        ## Template that defines a type of unit (e.g. "Soldier", "Tank").
        ## Unit instances hold a direct ref to their def.
        name*: string
        baseHealth*: int
        baseSpeed*: float
        baseArmor*: int
        visualKind*: VisualKind
        radius*: float    ## used for Circle units (half-width)
        width*: float     ## used for Rect units, in pixels
        height*: float    ## used for Rect units, in pixels

    Unit* = object
        ## A single unit instance on the battlefield.
        ## Does NOT store a chunkId — chunk membership is computed from pos via getChunkAtPosition.
        ## When alive=false the slot can be recycled by spawnUnit.
        id*: UnitId
        def*: UnitDef         ## direct ref to the unit definition
        factionId*: FactionId
        pos*: Vector2         ## absolute pixel position (center of the unit)
        health*: int
        alive*: bool

    UnitSystem* = ref object
        units*: seq[Unit]
        defs*: seq[UnitDef]


proc initUnitSystem*(): UnitSystem =
    var us = UnitSystem(units: @[], defs: @[])

    # Soldier — circle, radius 16px (1 tile)
    us.defs.add(UnitDef(
        name: "Soldier",
        baseHealth: 100,
        baseSpeed: 2.0,
        baseArmor: 0,
        visualKind: VisualKind.Circle,
        radius: 16.0,
        width: 0, height: 0
    ))

    # Tank — rect, 3x2 tiles (96x64 px)
    us.defs.add(UnitDef(
        name: "Tank",
        baseHealth: 300,
        baseSpeed: 1.0,
        baseArmor: 5,
        visualKind: VisualKind.Rect,
        radius: 0,
        width: 96.0, height: 64.0
    ))

    return us


proc spawnUnit*(us: UnitSystem, def: UnitDef, factionId: FactionId, pos: Vector2): UnitId =
    let id = newUnitId()
    let unit = Unit(
        id: id,
        def: def,
        factionId: factionId,
        pos: pos,
        health: def.baseHealth,
        alive: true
    )
    # Recycle a dead unit slot if available, otherwise append
    for i in 0 ..< us.units.len:
        if not us.units[i].alive:
            us.units[i] = unit
            return id
    us.units.add(unit)
    return id


proc removeUnit*(us: UnitSystem, id: UnitId) =
    for i in 0 ..< us.units.len:
        if us.units[i].id == id:
            us.units[i].alive = false
            return


proc getById*(us: UnitSystem, id: UnitId): Option[Unit] =
    for unit in us.units:
        if unit.id == id:
            return some(unit)
    return none(Unit)


proc getUnitsInRect*(us: UnitSystem, rect: Rectangle): seq[Unit] =
    ## Returns all alive units whose position falls within the given rectangle.
    result = @[]
    for unit in us.units:
        if unit.alive and
           unit.pos.x >= rect.x and unit.pos.x < rect.x + rect.width and
           unit.pos.y >= rect.y and unit.pos.y < rect.y + rect.height:
            result.add(unit)


proc drawUnits*(us: UnitSystem, diplomacySystem: DiplomacySystem) =
    ## Draws all alive units as placeholder shapes in faction color.
    ## TODO: Replace with proper sprites/graphics later.
    for unit in us.units:
        if not unit.alive: continue
        let color = diplomacySystem.getColor(unit.factionId)
        case unit.def.visualKind:
        of VisualKind.Circle:
            drawCircle(unit.pos.x.int32, unit.pos.y.int32, unit.def.radius.float32, color)
        of VisualKind.Rect:
            drawRectangle(
                (unit.pos.x - unit.def.width / 2).int32,
                (unit.pos.y - unit.def.height / 2).int32,
                unit.def.width.int32, unit.def.height.int32, color
            )


proc spawnTestUnits*(us: UnitSystem, mapWidthPx: int, mapHeightPx: int) =
    ## Spawns ~100 hardcoded test units randomly across the map.
    ## 70 Soldiers, 30 Tanks, alternating between factions 0 and 1.
    let soldierDef = us.defs[0]
    let tankDef = us.defs[1]

    for i in 0 ..< 70:
        let faction = FactionId(i mod 2)
        let pos = Vector2(
            x: rand(64 .. mapWidthPx - 64).float,
            y: rand(64 .. mapHeightPx - 64).float
        )
        discard us.spawnUnit(soldierDef, faction, pos)

    for i in 0 ..< 30:
        let faction = FactionId(i mod 2)
        let pos = Vector2(
            x: rand(96 .. mapWidthPx - 96).float,
            y: rand(96 .. mapHeightPx - 96).float
        )
        discard us.spawnUnit(tankDef, faction, pos)
