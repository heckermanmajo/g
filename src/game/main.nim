import std/options
import std/math
import std/random
import std/tables
import std/parsecfg
import std/os
import std/strutils

import raylib

import ../shared/types
import ../shared/mapio
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

    proc startNewGame(gs: var GameState, mapName: string) =
        gs.units = @[]
        gs.selectedUnits = @[]
        gs.selectedBuilding = -1
        gs.projectiles = @[]
        gs.explosions = @[]
        gs.grenades = @[]
        gs.effects = @[]
        gs.smokeParticles = @[]
        gs.debris = @[]
        gs.buildings = @[]
        gs.factions = @[]
        gs.gameOver = false
        gs.winnerFactionIndex = -1
        gs.spawnMenuOpen = false
        gs.uiHovered = false
        gs.isDragging = false
        gs.kraftTickTimer = 0

        block INIT_MAP:
            gs.map = loadMap(mapName, generateTiles = true)

        block INIT_CAMERA:
            gs.camera = Camera2D()
            gs.camera.target = Vector2(x: 0, y: 0)
            gs.camera.offset = Vector2(x: getScreenWidth().float / 2, y: getScreenHeight().float / 2)
            gs.camera.rotation = 0
            gs.camera.zoom = 1

        block INIT_FACTIONS:
            # Immer 4 Fraktions-Slots, damit factionIndex == spawnForFaction bleibt.
            # Slots ohne Spawn-Chunk werden sofort als defeated markiert.
            # factionIndex 0 = Spieler (rot), 1..3 = AI (blau, gruen, lila).
            var spawnPresent: array[4, bool]
            for c in gs.map.chunks:
                if c.kind == ChunkKind.Spawn and c.spawnForFaction >= 0 and c.spawnForFaction < 4:
                    spawnPresent[c.spawnForFaction] = true
            let factionNames = ["Rot", "Blau", "Gruen", "Lila"]
            let factionColors = [RED, BLUE, GREEN, PURPLE]
            gs.factions = @[]
            for i in 0 .. 3:
                gs.factions.add(Faction(
                    name: factionNames[i],
                    color: factionColors[i],
                    kraft: 500,
                    aiControlled: i != 0,
                    defeated: not spawnPresent[i]
                ))

        block DEBUG_SPAWN_ARTILLERY_TEST:
            var artIdx = -1
            var soldierIdx = -1
            var tankIdx = -1
            for i in 0 ..< gs.unitDefs.len:
                if gs.unitDefs[i].name == "Artillery": artIdx = i
                if gs.unitDefs[i].name == "RifleSoldier": soldierIdx = i
                if gs.unitDefs[i].name == "Tank": tankIdx = i
            if artIdx >= 0 and soldierIdx >= 0 and tankIdx >= 0:
                let testPos = Vector2(x: 500.0, y: 500.0)
                let artUnitIdx = gs.units.len
                gs.units.add(Unit(
                    definition: gs.unitDefs[artIdx], factionIndex: 0, position: testPos,
                    health: gs.unitDefs[artIdx].baseHealth, alive: true,
                    targetPosition: none(Vector2), finalPosition: none(Vector2),
                    path: @[], currentChunk: 0,
                    towedByUnit: -1, towingEmplacement: -1, towTarget: -1, assignedEmplacement: -1, inTransportOf: -1,
                    inBuilding: -1
                ))
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
                gs.units[artUnitIdx].crewIndices = @[crew1Idx, crew2Idx]
                gs.units.add(Unit(
                    definition: gs.unitDefs[tankIdx], factionIndex: 1,
                    position: Vector2(x: testPos.x + 1200.0, y: testPos.y),
                    health: gs.unitDefs[tankIdx].baseHealth, alive: true,
                    targetPosition: none(Vector2), finalPosition: none(Vector2),
                    path: @[], currentChunk: 0,
                    towedByUnit: -1, towingEmplacement: -1, towTarget: -1, assignedEmplacement: -1, inTransportOf: -1,
                    inBuilding: -1
                ))

        block INIT_BUILDINGS:
            let cps = gs.map.mapSizeInChunks
            let chunkPx = gs.map.chunkSizePixels
            let half = chunkPx.float / 2.0
            for mb in gs.map.buildings:
                let pos = Vector2(x: mb.chunkX.float * chunkPx.float + half,
                                  y: mb.chunkY.float * chunkPx.float + half)
                gs.buildings.add(Building(
                    kind: mb.kind,
                    position: pos,
                    health: 500,
                    maxHealth: 500,
                    alive: true,
                    factionIndex: -1,
                    occupantIndices: @[],
                    maxOccupants: 4,
                    currentChunk: mb.chunkX * cps + mb.chunkY,
                    rotation: 0.0
                ))

    var game = GameState()
    game.mode = GameMode.MainMenu

    block LOAD_DEFINITIONS:
        block INIT_GRENADES:
            game.grenadeDefs = @[]
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
                game.grenadeDefs.add(gdef)
            echo "Loaded ", game.grenadeDefs.len, " grenade definitions"

        block INIT_UNITS:
            game.unitDefs = @[]
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
                unitDefinition.texturePaths[0] = cfg.getSectionValue("Unit", "texturePathRed")
                unitDefinition.texturePaths[1] = cfg.getSectionValue("Unit", "texturePathBlue")
                unitDefinition.texturePaths[2] = cfg.getSectionValue("Unit", "texturePathGreen", "")
                unitDefinition.texturePaths[3] = cfg.getSectionValue("Unit", "texturePathPurple", "")
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
                    for gi in 0 ..< game.grenadeDefs.len:
                        if game.grenadeDefs[gi].name == grenadeType:
                            unitDefinition.grenadeDefIndex = gi
                            break
                    if unitDefinition.grenadeDefIndex < 0:
                        echo "WARNING: UnitDef '", unitDefinition.name, "' references unknown grenade '", grenadeType, "'"
                unitDefinition.grenadeStartAmmo = cfg.getSectionValue("Unit", "grenadeStartAmmo", "0").parseInt
                game.unitDefs.add(unitDefinition)

        block INIT_TROOPS:
            game.troopDefs = @[]
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
                    for i in 0 ..< game.unitDefs.len:
                        if game.unitDefs[i].name == unitName:
                            defIdx = i
                            break
                    if defIdx >= 0:
                        troop.entries.add(TroopEntry(unitDefIndex: defIdx, count: count))
                    else:
                        echo "WARNING: TroopDef '", troop.name, "' references unknown unit '", unitName, "'"
                game.troopDefs.add(troop)
            echo "Loaded ", game.troopDefs.len, " troop definitions"

    block LOAD_TEXTURES:
        for i in 1..6:
            game.textures["gras" & $i] = loadTexture("res/tiles/gras" & $i & ".png")
        for ud in game.unitDefs:
            for tp in ud.texturePaths:
                if tp != "" and tp notin game.textures:
                    game.textures[tp] = loadTexture(tp)
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
            case game.mode
            of GameMode.MainMenu:
                drawMainMenu(game)
                if game.quitRequested:
                    endDrawing()
                    break
            of GameMode.MapSelect:
                drawMapSelect(game)
                if game.startGameRequested:
                    game.startGameRequested = false
                    startNewGame(game, game.selectedMapName)
                    game.mode = GameMode.Playing
            of GameMode.Playing:
                handleInput(game)
                updateGame(game)
                updateAI(game)
                drawGame(game)
                drawUI(game)
                if game.returnToMenuRequested:
                    game.returnToMenuRequested = false
                    game.mode = GameMode.MainMenu
            endDrawing()

    block CLEANUP:
        game.textures.clear()
        closeWindow()
