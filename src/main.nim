import std/options
import std/math
import std/random
import std/tables
import std/parsecfg
import std/os
import std/strutils

import raylib

import types
import update
import draw
import input
import ui
import ai

block BLOCK_SO_WE_DONT_SEGFAULT_DUE_TO_NIM_GARBAGE_COLLECTOR:

    block INIT:
        randomize()
        setConfigFlags(flags(FullscreenMode))
        initWindow(getScreenWidth(), getScreenHeight(), "Nim Raylib Example")
        setTargetFPS(60)

    var game = block:
        var gs = GameState()
        gs.gameOver = false
        gs.winnerFactionIndex = -1

        block INIT_MAP:
            let chunksPerSide = 20
            let chunkSizeInTiles = 10
            gs.map.mapSizeInChunks = chunksPerSide
            gs.map.chunkSizeInTiles = chunkSizeInTiles
            gs.map.chunkSizePixels = chunkSizeInTiles * PIXELS_PER_TILE
            gs.map.mapSizePixels = chunksPerSide * gs.map.chunkSizePixels
            gs.map.chunks = @[]
            for chunkX in 0 ..< chunksPerSide:
                for chunkY in 0 ..< chunksPerSide:
                    var chunk = Chunk()
                    chunk.x = chunkX * chunkSizeInTiles * PIXELS_PER_TILE
                    chunk.y = chunkY * chunkSizeInTiles * PIXELS_PER_TILE
                    chunk.currentOwner = -1
                    chunk.spawnForFaction = -1
                    chunk.unitIndices = @[]

                    # Mountain: Gebirgszug in der Mitte
                    if chunkX in 8..11 and chunkY in 6..8:
                        chunk.kind = ChunkKind.Mountain
                    # Water: Fluss vertikal
                    elif chunkX == 5 and chunkY in 3..16:
                        chunk.kind = ChunkKind.Water
                    elif chunkX == 6 and chunkY in 5..14:
                        chunk.kind = ChunkKind.Water
                    # Spawn Fraktion 0 (links)
                    elif chunkX == 0 and chunkY in 9..10:
                        chunk.kind = ChunkKind.Spawn
                        chunk.spawnForFaction = 0
                        chunk.currentOwner = 0
                    # Spawn Fraktion 1 (rechts)
                    elif chunkX == 19 and chunkY in 9..10:
                        chunk.kind = ChunkKind.Spawn
                        chunk.spawnForFaction = 1
                        chunk.currentOwner = 1
                    else:
                        chunk.kind = ChunkKind.Grass

                    chunk.passable = chunk.kind notin {ChunkKind.Mountain, ChunkKind.Water}

                    let tileKind = case chunk.kind:
                        of ChunkKind.Grass: TileKind.Grass
                        of ChunkKind.Mountain: TileKind.Mountain
                        of ChunkKind.Water: TileKind.Water
                        of ChunkKind.Spawn: TileKind.Spawn
                    chunk.tiles = @[]
                    for tileX in 0 ..< chunkSizeInTiles:
                        for tileY in 0 ..< chunkSizeInTiles:
                            let textureKey = if tileKind in {TileKind.Grass, TileKind.Spawn}: "gras" & $(rand(1..6))
                                        else: ""
                            chunk.tiles.add(Tile(
                                x: chunk.x + tileX * PIXELS_PER_TILE,
                                y: chunk.y + tileY * PIXELS_PER_TILE,
                                passable: chunk.passable,
                                kind: tileKind,
                                textureKey: textureKey
                            ))

                    gs.map.chunks.add(chunk)

            block INIT_BONUS_CHUNKS:
                let cps = chunksPerSide
                let oneShot = [(10, 15), (10, 2)]
                let perSec = [(4, 10), (15, 10)]
                for (cx, cy) in oneShot:
                    let idx = cx * cps + cy
                    gs.map.chunks[idx].kraftBonusOnCapture = 100
                for (cx, cy) in perSec:
                    let idx = cx * cps + cy
                    gs.map.chunks[idx].kraftPerSecond = 5

        block INIT_CAMERA:
            gs.camera = Camera2D()
            gs.camera.target = Vector2(x: 0, y: 0)
            gs.camera.offset = Vector2(x: getScreenWidth().float / 2, y: getScreenHeight().float / 2)
            gs.camera.rotation = 0
            gs.camera.zoom = 1

        block INIT_FACTIONS:
            gs.factions = @[
                Faction(name: "Faction 1", color: RED, kraft: 500, aiControlled: false),
                Faction(name: "Faction 2", color: BLUE, kraft: 500, aiControlled: true)
            ]

        block INIT_GRENADES:
            gs.grenadeDefs = @[]
            for file in walkDir("res/grenades"):
                if file.kind != pcFile or not file.path.endsWith(".ini"): continue
                let cfg = loadConfig(file.path)
                var gdef = GrenadeDef()
                gdef.name = cfg.getSectionValue("Grenade", "name")
                gdef.range = cfg.getSectionValue("Grenade", "range").parseFloat
                gdef.damage = cfg.getSectionValue("Grenade", "damage").parseInt
                gdef.cooldown = cfg.getSectionValue("Grenade", "cooldown").parseFloat
                gdef.flightDuration = cfg.getSectionValue("Grenade", "flightDuration").parseFloat
                gdef.fuseTimer = cfg.getSectionValue("Grenade", "fuseTimer").parseFloat
                gdef.explosionRadiusHeavy = cfg.getSectionValue("Grenade", "explosionRadiusHeavy").parseFloat
                gdef.explosionRadiusMedium = cfg.getSectionValue("Grenade", "explosionRadiusMedium").parseFloat
                gdef.explosionRadiusLight = cfg.getSectionValue("Grenade", "explosionRadiusLight").parseFloat
                gdef.targetCategory = parseEnum[DamageCategory](cfg.getSectionValue("Grenade", "targetCategory"))
                gs.grenadeDefs.add(gdef)
            echo "Loaded ", gs.grenadeDefs.len, " grenade definitions"

        block INIT_UNITS:
            gs.unitDefs = @[]
            for file in walkDir("res/units"):
                if file.kind != pcFile or not file.path.endsWith(".ini"): continue
                let cfg = loadConfig(file.path)
                var unitDefinition = UnitDef()
                unitDefinition.name = cfg.getSectionValue("Unit", "name")
                unitDefinition.baseHealth = cfg.getSectionValue("Unit", "baseHealth").parseInt
                unitDefinition.baseSpeed = cfg.getSectionValue("Unit", "baseSpeed").parseFloat
                unitDefinition.baseArmor = cfg.getSectionValue("Unit", "baseArmor").parseInt
                unitDefinition.visualKind = parseEnum[VisualKind](cfg.getSectionValue("Unit", "visualKind"))
                unitDefinition.radius = cfg.getSectionValue("Unit", "radius").parseFloat
                unitDefinition.width = cfg.getSectionValue("Unit", "width").parseFloat
                unitDefinition.height = cfg.getSectionValue("Unit", "height").parseFloat
                unitDefinition.damageCategory = parseEnum[DamageCategory](cfg.getSectionValue("Unit", "damageCategory"))
                unitDefinition.attackRange = cfg.getSectionValue("Unit", "attackRange").parseFloat
                unitDefinition.attackDamage = cfg.getSectionValue("Unit", "attackDamage").parseInt
                unitDefinition.attackCooldown = cfg.getSectionValue("Unit", "attackCooldown").parseFloat
                unitDefinition.explosionRadiusHeavy = cfg.getSectionValue("Unit", "explosionRadiusHeavy").parseFloat
                unitDefinition.explosionRadiusMedium = cfg.getSectionValue("Unit", "explosionRadiusMedium").parseFloat
                unitDefinition.explosionRadiusLight = cfg.getSectionValue("Unit", "explosionRadiusLight").parseFloat
                unitDefinition.kraftCost = cfg.getSectionValue("Unit", "kraftCost").parseInt
                unitDefinition.texturePathRed = cfg.getSectionValue("Unit", "texturePathRed")
                unitDefinition.texturePathBlue = cfg.getSectionValue("Unit", "texturePathBlue")
                unitDefinition.texturePathNeutral = cfg.getSectionValue("Unit", "texturePathNeutral", "")
                unitDefinition.canTransport = cfg.getSectionValue("Unit", "canTransport") == "true"
                unitDefinition.maxPassengers = cfg.getSectionValue("Unit", "maxPassengers").parseInt
                unitDefinition.isEmplacement = cfg.getSectionValue("Unit", "isEmplacement") == "true"
                unitDefinition.crewSlots = cfg.getSectionValue("Unit", "crewSlots", "0").parseInt
                unitDefinition.canBeTowed = cfg.getSectionValue("Unit", "canBeTowed") == "true"
                unitDefinition.handPushSpeed = cfg.getSectionValue("Unit", "handPushSpeed", "0").parseFloat
                unitDefinition.deadTexturePath = cfg.getSectionValue("Unit", "deadTexturePath", "")
                let grenadeType = cfg.getSectionValue("Unit", "grenadeType", "")
                unitDefinition.grenadeDefIndex = -1
                if grenadeType != "":
                    for gi in 0 ..< gs.grenadeDefs.len:
                        if gs.grenadeDefs[gi].name == grenadeType:
                            unitDefinition.grenadeDefIndex = gi
                            break
                    if unitDefinition.grenadeDefIndex < 0:
                        echo "WARNING: UnitDef '", unitDefinition.name, "' references unknown grenade '", grenadeType, "'"
                unitDefinition.grenadeStartAmmo = cfg.getSectionValue("Unit", "grenadeStartAmmo", "0").parseInt
                gs.unitDefs.add(unitDefinition)

        block INIT_TROOPS:
            gs.troopDefs = @[]
            for file in walkDir("res/troops"):
                if file.kind != pcFile or not file.path.endsWith(".ini"): continue
                let cfg = loadConfig(file.path)
                var troop = TroopDef()
                troop.name = cfg.getSectionValue("Troop", "name")
                troop.kraftCost = cfg.getSectionValue("Troop", "kraftCost").parseInt
                troop.entries = @[]
                let unitsStr = cfg.getSectionValue("Troop", "units")
                for part in unitsStr.split(","):
                    let pair = part.strip().split("/")
                    let unitName = pair[0]
                    let count = pair[1].parseInt
                    var defIdx = -1
                    for i in 0 ..< gs.unitDefs.len:
                        if gs.unitDefs[i].name == unitName:
                            defIdx = i
                            break
                    if defIdx >= 0:
                        troop.entries.add(TroopEntry(unitDefIndex: defIdx, count: count))
                    else:
                        echo "WARNING: TroopDef '", troop.name, "' references unknown unit '", unitName, "'"
                gs.troopDefs.add(troop)
            echo "Loaded ", gs.troopDefs.len, " troop definitions"

        block DEBUG_SPAWN_ARTILLERY_TEST:
            # Finde UnitDef-Indices
            var artIdx = -1
            var soldierIdx = -1
            var tankIdx = -1
            for i in 0 ..< gs.unitDefs.len:
                if gs.unitDefs[i].name == "Artillery": artIdx = i
                if gs.unitDefs[i].name == "RifleSoldier": soldierIdx = i
                if gs.unitDefs[i].name == "Tank": tankIdx = i
            if artIdx >= 0 and soldierIdx >= 0 and tankIdx >= 0:
                let testPos = Vector2(x: 500.0, y: 500.0)
                # Artillerie (Spieler, Faction 0)
                let artUnitIdx = gs.units.len
                gs.units.add(Unit(
                    definition: gs.unitDefs[artIdx], factionIndex: 0, position: testPos,
                    health: gs.unitDefs[artIdx].baseHealth, alive: true,
                    targetPosition: none(Vector2), finalPosition: none(Vector2),
                    path: @[], currentChunk: 0,
                    towedByUnit: -1, towingEmplacement: -1, towTarget: -1, assignedEmplacement: -1, inTransportOf: -1,
                    inBuilding: -1
                ))
                # Crew-Soldat 1
                let crew1Idx = gs.units.len
                gs.units.add(Unit(
                    definition: gs.unitDefs[soldierIdx], factionIndex: 0,
                    position: Vector2(x: testPos.x - 20.0, y: testPos.y + 25.0),
                    health: gs.unitDefs[soldierIdx].baseHealth, alive: true,
                    targetPosition: none(Vector2), finalPosition: none(Vector2),
                    path: @[], currentChunk: 0,
                    towedByUnit: -1, towingEmplacement: -1, towTarget: -1,
                    assignedEmplacement: artUnitIdx, inTransportOf: -1,
                    inBuilding: -1
                ))
                # Crew-Soldat 2
                let crew2Idx = gs.units.len
                gs.units.add(Unit(
                    definition: gs.unitDefs[soldierIdx], factionIndex: 0,
                    position: Vector2(x: testPos.x + 20.0, y: testPos.y + 25.0),
                    health: gs.unitDefs[soldierIdx].baseHealth, alive: true,
                    targetPosition: none(Vector2), finalPosition: none(Vector2),
                    path: @[], currentChunk: 0,
                    towedByUnit: -1, towingEmplacement: -1, towTarget: -1,
                    assignedEmplacement: artUnitIdx, inTransportOf: -1,
                    inBuilding: -1
                ))
                # Crew an Artillerie zuweisen
                gs.units[artUnitIdx].crewIndices = @[crew1Idx, crew2Idx]
                # Feindlicher Panzer 1200px entfernt (innerhalb attackRange=1600)
                gs.units.add(Unit(
                    definition: gs.unitDefs[tankIdx], factionIndex: 1,
                    position: Vector2(x: testPos.x + 1200.0, y: testPos.y),
                    health: gs.unitDefs[tankIdx].baseHealth, alive: true,
                    targetPosition: none(Vector2), finalPosition: none(Vector2),
                    path: @[], currentChunk: 0,
                    towedByUnit: -1, towingEmplacement: -1, towTarget: -1, assignedEmplacement: -1, inTransportOf: -1,
                    inBuilding: -1
                ))
                echo "DEBUG: Artillery test spawned - Art[", artUnitIdx, "] Crew[", crew1Idx, ",", crew2Idx, "] Enemy at 400px"

        block INIT_BUILDINGS:
            let cps = gs.map.mapSizeInChunks
            let chunkPx = gs.map.chunkSizePixels
            let half = chunkPx.float / 2.0
            let bunkerSpecs = [
                (2, 9, 0),
                (2, 10, 0),
                (17, 9, 1),
                (17, 10, 1)
            ]
            for (cx, cy, faction) in bunkerSpecs:
                let pos = Vector2(x: cx.float * chunkPx.float + half, y: cy.float * chunkPx.float + half)
                gs.buildings.add(Building(
                    kind: BuildingKind.Bunker,
                    position: pos,
                    health: 500,
                    maxHealth: 500,
                    alive: true,
                    factionIndex: faction,
                    occupantIndices: @[],
                    maxOccupants: 4,
                    currentChunk: cx * cps + cy,
                    rotation: 0.0
                ))

        gs

    block LOAD_TEXTURES:
        for i in 1..6:
            game.textures["gras" & $i] = loadTexture("res/tiles/gras" & $i & ".png")
        for ud in game.unitDefs:
            if ud.texturePathRed != "":
                game.textures[ud.texturePathRed] = loadTexture(ud.texturePathRed)
            if ud.texturePathBlue != "":
                game.textures[ud.texturePathBlue] = loadTexture(ud.texturePathBlue)
            if ud.texturePathNeutral != "":
                game.textures[ud.texturePathNeutral] = loadTexture(ud.texturePathNeutral)
            if ud.deadTexturePath != "" and ud.deadTexturePath notin game.textures:
                game.textures[ud.deadTexturePath] = loadTexture(ud.deadTexturePath)
        game.textures["fire1"] = loadTexture("res/effects/fire1.png")
        game.textures["fire2"] = loadTexture("res/effects/fire2.png")
        game.textures["hole"] = loadTexture("res/effects/hole.png")

    block GAME_LOOP:
        while not windowShouldClose():
            beginDrawing()
            handleInput(game)
            updateGame(game)
            updateAI(game)
            drawGame(game)
            drawUI(game)
            endDrawing()

    block CLEANUP:
        game.textures.clear()
        closeWindow()

