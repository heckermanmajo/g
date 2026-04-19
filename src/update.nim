import std/options
import std/math
import std/random

import raylib

import types
import combat

const SEPARATION_RADIUS = 40.0
const SEPARATION_STRENGTH = 1.5

proc updateGame*(game: var GameState) =
    let chunkSizePixels = game.map.chunkSizePixels
    let mapSizePixels = game.map.mapSizePixels

    block UPDATE_SHOOT_PAUSE:
        let deltaTime = getFrameTime()
        for i in 0 ..< game.units.len:
            if game.units[i].shootPauseTimer > 0:
                game.units[i].shootPauseTimer -= deltaTime

    block UPDATE_MOVEMENT:
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if game.units[i].inTransportOf >= 0: continue
            if game.units[i].towedByUnit >= 0: continue  # wird vom LKW gezogen, nicht selbst bewegen
            # Soldat am Geschuetz: nur stoppen wenn er schon angekommen ist (kein targetPosition)
            if game.units[i].assignedEmplacement >= 0 and game.units[i].targetPosition.isNone: continue
            # Emplacement braucht volle Crew zum Bewegen (von Hand schieben)
            if game.units[i].definition.isEmplacement:
                if game.units[i].crewIndices.len < game.units[i].definition.crewSlots:
                    game.units[i].targetPosition = none(Vector2)
                    game.units[i].finalPosition = none(Vector2)
                    game.units[i].path = @[]
                    continue
            if game.units[i].shootPauseTimer > 0: continue
            if game.units[i].targetPosition.isNone: continue
            let target = game.units[i].targetPosition.get()
            let dx = target.x - game.units[i].position.x
            let dy = target.y - game.units[i].position.y
            let dist = sqrt(dx * dx + dy * dy)
            let speed = game.units[i].definition.baseSpeed
            if dist <= speed:
                game.units[i].position = target
                if game.units[i].path.len > 0:
                    let nextChunk = game.units[i].path[0]
                    game.units[i].path.delete(0)
                    if game.units[i].path.len == 0:
                        game.units[i].targetPosition = game.units[i].finalPosition
                    else:
                        let chunk = game.map.chunks[nextChunk]
                        let half = chunkSizePixels.float / 2.0
                        game.units[i].targetPosition = some(Vector2(x: chunk.x.float + half, y: chunk.y.float + half))
                else:
                    game.units[i].targetPosition = none(Vector2)
                    game.units[i].finalPosition = none(Vector2)
            else:
                game.units[i].position.x += dx / dist * speed
                game.units[i].position.y += dy / dist * speed
                game.units[i].rotation = arctan2(dx, -dy) * 180.0 / PI

    block UPDATE_IDLE_TIMER:
        let deltaTime = getFrameTime()
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if game.units[i].inTransportOf >= 0: continue
            if game.units[i].targetPosition.isSome:
                game.units[i].idleTimer = 0
            else:
                game.units[i].idleTimer += deltaTime

    block UPDATE_CHUNK_TRACKING:
        for i in 0 ..< game.map.chunks.len:
            game.map.chunks[i].unitIndices = @[]
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if game.units[i].inTransportOf >= 0: continue
            let chunkX = clamp(game.units[i].position.x.int, 0, mapSizePixels - 1) div chunkSizePixels
            let chunkY = clamp(game.units[i].position.y.int, 0, mapSizePixels - 1) div chunkSizePixels
            let chunkIdx = chunkX * game.map.mapSizeInChunks + chunkY
            game.units[i].currentChunk = chunkIdx
            game.map.chunks[chunkIdx].unitIndices.add(i)

    block UPDATE_CHUNK_OWNERSHIP:
        for i in 0 ..< game.map.chunks.len:
            if not game.map.chunks[i].passable: continue
            var factionsSeen: set[uint8] = {}
            var lastFaction = -1
            for unitIdx in game.map.chunks[i].unitIndices:
                let faction = game.units[unitIdx].factionIndex
                if faction < 0: continue  # neutrale Units zaehlen nicht
                factionsSeen.incl(faction.uint8)
                lastFaction = faction
            if factionsSeen.card == 0:
                discard  # kein Unit da, Owner bleibt wie er ist
            elif factionsSeen.card == 1:
                let prevOwner = game.map.chunks[i].currentOwner
                game.map.chunks[i].currentOwner = lastFaction
                if prevOwner != lastFaction and
                   game.map.chunks[i].kraftBonusOnCapture > 0 and
                   not game.map.chunks[i].kraftBonusClaimed:
                    game.factions[lastFaction].kraft += game.map.chunks[i].kraftBonusOnCapture
                    game.map.chunks[i].kraftBonusClaimed = true
            else:
                game.map.chunks[i].currentOwner = -1  # umkaempft

    block UPDATE_TOW_COUPLING:
        # LKW koppelt Geschuetz an wenn er sein towTarget erreicht hat
        let towCoupleRadius = 60.0
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if game.units[i].towTarget < 0: continue  # kein Ziel-Geschuetz
            if game.units[i].towingEmplacement >= 0: continue  # zieht schon eins
            let targetIdx = game.units[i].towTarget
            if not game.units[targetIdx].alive:
                game.units[i].towTarget = -1
                continue
            if game.units[targetIdx].towedByUnit >= 0:
                game.units[i].towTarget = -1  # schon von jemand anderem angekoppelt
                continue
            let dx = game.units[i].position.x - game.units[targetIdx].position.x
            let dy = game.units[i].position.y - game.units[targetIdx].position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist <= towCoupleRadius:
                game.units[i].towingEmplacement = targetIdx
                game.units[i].towTarget = -1
                game.units[targetIdx].towedByUnit = i
                game.units[targetIdx].factionIndex = game.units[i].factionIndex
                # Crew in LKW laden falls Platz, sonst entlassen
                for crewIdx in game.units[targetIdx].crewIndices:
                    game.units[crewIdx].assignedEmplacement = -1
                    let maxP = game.units[i].definition.maxPassengers
                    if game.units[i].passengerIndices.len < maxP:
                        game.units[crewIdx].inTransportOf = i
                        game.units[i].passengerIndices.add(crewIdx)
                game.units[targetIdx].crewIndices = @[]

    block UPDATE_TOWED_EMPLACEMENT:
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            let towIdx = game.units[i].towingEmplacement
            if towIdx < 0: continue
            if not game.units[towIdx].alive:
                game.units[i].towingEmplacement = -1
                continue
            # Geschuetz folgt dem LKW — Offset hinter Fahrtrichtung
            let rot = game.units[i].rotation * PI / 180.0
            let offsetDist = 50.0
            game.units[towIdx].position.x = game.units[i].position.x - sin(rot) * offsetDist
            game.units[towIdx].position.y = game.units[i].position.y + cos(rot) * offsetDist
            game.units[towIdx].rotation = game.units[i].rotation
            game.units[towIdx].currentChunk = game.units[i].currentChunk

    block UPDATE_CREW_POSITIONS:
        # Crew-Soldaten sitzen an festen Positionen am Geschuetz
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if not game.units[i].definition.isEmplacement: continue
            var j = 0
            while j < game.units[i].crewIndices.len:
                let crewIdx = game.units[i].crewIndices[j]
                if not game.units[crewIdx].alive:
                    # Crew-Soldat ist tot, aus crewIndices entfernen
                    game.units[crewIdx].assignedEmplacement = -1
                    game.units[i].crewIndices.delete(j)
                    continue
                # Positioniere Crew-Soldat hinter dem Geschuetz (rotiert mit)
                let rot = game.units[i].rotation * PI / 180.0
                # "Hinter" = entgegen der Blickrichtung, Slots seitlich versetzt
                let slots = game.units[i].definition.crewSlots
                let sideOffset = (j.float - (slots.float - 1.0) / 2.0) * 20.0  # seitlich verteilen
                let backOffset = 25.0  # hinter dem Geschuetz
                # Blickrichtung ist sin(rot), -cos(rot) — "hinten" ist umgekehrt
                game.units[crewIdx].position.x = game.units[i].position.x - sin(rot) * backOffset + cos(rot) * sideOffset
                game.units[crewIdx].position.y = game.units[i].position.y + cos(rot) * backOffset + sin(rot) * sideOffset
                game.units[crewIdx].rotation = game.units[i].rotation
                game.units[crewIdx].currentChunk = game.units[i].currentChunk
                j += 1
            # Geschuetz wird neutral wenn keine Crew mehr da ist
            if game.units[i].crewIndices.len == 0 and game.units[i].towedByUnit < 0:
                game.units[i].factionIndex = -1

    block UPDATE_CREW_AUTO_ASSIGN:
        # Idle-Soldaten in der Naehe eines unbesetzten Geschuetzes laufen hin
        # Leere Geschuetze koennen von jeder Fraktion uebernommen werden
        let autoAssignRadius = 200.0
        let crewArriveRadius = 30.0
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if not game.units[i].definition.isEmplacement: continue
            if game.units[i].towedByUnit >= 0: continue  # wird gezogen, keine Crew zuweisen
            if game.units[i].crewIndices.len >= game.units[i].definition.crewSlots: continue
            let emplacementPos = game.units[i].position
            let isEmpty = game.units[i].crewIndices.len == 0
            # Suche idle Soldaten in der Naehe
            for j in 0 ..< game.units.len:
                if game.units[i].crewIndices.len >= game.units[i].definition.crewSlots: break
                if not game.units[j].alive: continue
                if game.units[j].inTransportOf >= 0: continue
                if game.units[j].assignedEmplacement >= 0: continue  # schon zugewiesen
                # Nur gleiche Fraktion, oder jede Fraktion wenn komplett leer
                if not isEmpty and game.units[j].factionIndex != game.units[i].factionIndex: continue
                if game.units[j].definition.damageCategory != DamageCategory.Light: continue
                if game.units[j].definition.isEmplacement: continue
                if game.units[j].definition.canTransport: continue
                let dx = game.units[j].position.x - emplacementPos.x
                let dy = game.units[j].position.y - emplacementPos.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > autoAssignRadius: continue
                if game.units[j].idleTimer < 1.0: continue  # muss mindestens 1s idle sein
                if dist <= crewArriveRadius:
                    # Soldat ist angekommen — Crew zuweisen
                    if isEmpty:
                        game.units[i].factionIndex = game.units[j].factionIndex  # Uebernahme
                    game.units[j].assignedEmplacement = i
                    game.units[j].targetPosition = none(Vector2)
                    game.units[j].finalPosition = none(Vector2)
                    game.units[j].path = @[]
                    game.units[i].crewIndices.add(j)
                else:
                    # Soldat muss noch hinlaufen
                    if game.units[j].targetPosition.isNone:
                        game.units[j].targetPosition = some(emplacementPos)
                        game.units[j].assignedEmplacement = i  # reserviere den Slot
                        game.units[i].crewIndices.add(j)
                        if isEmpty:
                            game.units[i].factionIndex = game.units[j].factionIndex

    block UPDATE_BUILDING_CHUNK_TRACKING:
        for i in 0 ..< game.buildings.len:
            if not game.buildings[i].alive: continue
            let chunkX = clamp(game.buildings[i].position.x.int, 0, mapSizePixels - 1) div chunkSizePixels
            let chunkY = clamp(game.buildings[i].position.y.int, 0, mapSizePixels - 1) div chunkSizePixels
            game.buildings[i].currentChunk = chunkX * game.map.mapSizeInChunks + chunkY

    block UPDATE_BUILDING_OCCUPANT_ASSIGN:
        let autoAssignRadius = 200.0
        let buildingArriveRadius = 30.0
        for i in 0 ..< game.buildings.len:
            if not game.buildings[i].alive: continue
            if game.buildings[i].kind != BuildingKind.Bunker: continue
            if game.buildings[i].occupantIndices.len >= game.buildings[i].maxOccupants: continue
            let buildingPos = game.buildings[i].position
            let isEmpty = game.buildings[i].occupantIndices.len == 0
            for j in 0 ..< game.units.len:
                if game.buildings[i].occupantIndices.len >= game.buildings[i].maxOccupants: break
                if not game.units[j].alive: continue
                if game.units[j].inTransportOf >= 0: continue
                if game.units[j].assignedEmplacement >= 0: continue
                if game.units[j].inBuilding >= 0: continue
                if not isEmpty and game.units[j].factionIndex != game.buildings[i].factionIndex: continue
                if game.units[j].definition.damageCategory != DamageCategory.Light: continue
                if game.units[j].definition.isEmplacement: continue
                if game.units[j].definition.canTransport: continue
                let dx = game.units[j].position.x - buildingPos.x
                let dy = game.units[j].position.y - buildingPos.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > autoAssignRadius: continue
                if dist <= buildingArriveRadius:
                    if isEmpty:
                        game.buildings[i].factionIndex = game.units[j].factionIndex
                    game.units[j].inBuilding = i
                    game.units[j].inTransportOf = i
                    game.units[j].targetPosition = none(Vector2)
                    game.units[j].finalPosition = none(Vector2)
                    game.units[j].path = @[]
                    game.buildings[i].occupantIndices.add(j)

    block UPDATE_BUILDING_CLEANUP:
        for i in 0 ..< game.buildings.len:
            if not game.buildings[i].alive: continue
            var k = 0
            while k < game.buildings[i].occupantIndices.len:
                let occIdx = game.buildings[i].occupantIndices[k]
                if not game.units[occIdx].alive:
                    game.buildings[i].occupantIndices.delete(k)
                else:
                    k += 1
            if game.buildings[i].health <= 0:
                game.buildings[i].alive = false
                for occIdx in game.buildings[i].occupantIndices:
                    let offset = Vector2(x: rand(-20.0..20.0), y: rand(-20.0..20.0))
                    game.units[occIdx].inBuilding = -1
                    game.units[occIdx].inTransportOf = -1
                    game.units[occIdx].position = Vector2(
                        x: game.buildings[i].position.x + offset.x,
                        y: game.buildings[i].position.y + offset.y
                    )
                    game.units[occIdx].health = game.units[occIdx].definition.baseHealth div 2
                game.buildings[i].occupantIndices = @[]

    block UPDATE_SEPARATION:
        for i in 0 ..< game.map.chunks.len:
            let indices = game.map.chunks[i].unitIndices
            if indices.len < 2: continue
            for a in 0 ..< indices.len:
                for b in (a + 1) ..< indices.len:
                    let ai = indices[a]
                    let bi = indices[b]
                    if not game.units[ai].alive or not game.units[bi].alive: continue
                    if game.units[ai].assignedEmplacement >= 0 or game.units[bi].assignedEmplacement >= 0: continue
                    if game.units[ai].towedByUnit >= 0 or game.units[bi].towedByUnit >= 0: continue
                    let dx = game.units[ai].position.x - game.units[bi].position.x
                    let dy = game.units[ai].position.y - game.units[bi].position.y
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist < SEPARATION_RADIUS and dist > 0.01:
                        let factor = SEPARATION_STRENGTH * (1.0 - dist / SEPARATION_RADIUS)
                        let nx = dx / dist * factor
                        let ny = dy / dist * factor
                        game.units[ai].position.x += nx
                        game.units[ai].position.y += ny
                        game.units[bi].position.x -= nx
                        game.units[bi].position.y -= ny

    updateCombat(game)

    block UPDATE_SPAWN_QUEUE:
        let deltaTime = getFrameTime()
        for factionIdx in 0 ..< game.factions.len:
            # Einzel-Spawns (legacy)
            var j = 0
            while j < game.factions[factionIdx].spawnQueue.len:
                game.factions[factionIdx].spawnQueue[j].timer -= deltaTime
                if game.factions[factionIdx].spawnQueue[j].timer <= 0:
                    let req = game.factions[factionIdx].spawnQueue[j]
                    let chunk = game.map.chunks[req.spawnChunkIndex]
                    let margin = 20.0
                    let spawnPosition = Vector2(
                        x: chunk.x.float + margin + rand(chunkSizePixels.float - 2 * margin),
                        y: chunk.y.float + margin + rand(chunkSizePixels.float - 2 * margin)
                    )
                    let unitDefinition = game.unitDefs[req.unitDefIndex]
                    var newUnit = Unit(
                        definition: unitDefinition, factionIndex: req.factionIndex, position: spawnPosition,
                        health: unitDefinition.baseHealth, alive: true,
                        targetPosition: none(Vector2), finalPosition: none(Vector2),
                        path: @[], currentChunk: req.spawnChunkIndex,
                        towedByUnit: -1, towingEmplacement: -1, towTarget: -1, assignedEmplacement: -1, inTransportOf: -1,
                        inBuilding: -1,
                        grenadeAmmo: unitDefinition.grenadeStartAmmo
                    )
                    game.units.add(newUnit)
                    game.factions[factionIdx].spawnQueue.delete(j)
                else:
                    j += 1

            # Trupp-Spawns
            var t = 0
            while t < game.factions[factionIdx].troopSpawnQueue.len:
                game.factions[factionIdx].troopSpawnQueue[t].timer -= deltaTime
                if game.factions[factionIdx].troopSpawnQueue[t].timer <= 0:
                    let req = game.factions[factionIdx].troopSpawnQueue[t]
                    let troop = game.troopDefs[req.troopDefIndex]
                    let chunk = game.map.chunks[req.spawnChunkIndex]
                    let margin = 20.0

                    # Alle Units des Trupps spawnen und Indices merken
                    var transportIndices: seq[int] = @[]  # Trucks, Jeeps, APCs
                    var emplacementIndices: seq[int] = @[]  # Geschuetze
                    var soldierIndices: seq[int] = @[]  # Infanterie

                    for entry in troop.entries:
                        let unitDef = game.unitDefs[entry.unitDefIndex]
                        for _ in 0 ..< entry.count:
                            let spawnPos = Vector2(
                                x: chunk.x.float + margin + rand(chunkSizePixels.float - 2 * margin),
                                y: chunk.y.float + margin + rand(chunkSizePixels.float - 2 * margin)
                            )
                            let unitIdx = game.units.len
                            game.units.add(Unit(
                                definition: unitDef, factionIndex: req.factionIndex, position: spawnPos,
                                health: unitDef.baseHealth, alive: true,
                                targetPosition: none(Vector2), finalPosition: none(Vector2),
                                path: @[], currentChunk: req.spawnChunkIndex,
                                towedByUnit: -1, towingEmplacement: -1, towTarget: -1, assignedEmplacement: -1, inTransportOf: -1,
                                inBuilding: -1,
                                grenadeAmmo: unitDef.grenadeStartAmmo
                            ))
                            if unitDef.canTransport:
                                transportIndices.add(unitIdx)
                            elif unitDef.isEmplacement:
                                emplacementIndices.add(unitIdx)
                            elif unitDef.damageCategory == DamageCategory.Light:
                                soldierIndices.add(unitIdx)
                            # Heavy/Medium (Panzer etc.) bleiben eigenstaendig

                    # Geschuetze an Transporter anhaengen
                    var towIdx = 0
                    for emplIdx in emplacementIndices:
                        if towIdx >= transportIndices.len: break
                        let trIdx = transportIndices[towIdx]
                        if game.units[trIdx].towingEmplacement >= 0:
                            towIdx += 1
                            if towIdx >= transportIndices.len: break
                        game.units[trIdx].towingEmplacement = emplIdx
                        game.units[emplIdx].towedByUnit = trIdx
                        game.units[emplIdx].position = game.units[trIdx].position
                        towIdx += 1

                    # Crew an Geschuetze zuweisen
                    var soldierCursor = 0
                    for emplIdx in emplacementIndices:
                        let slots = game.units[emplIdx].definition.crewSlots
                        for _ in 0 ..< slots:
                            if soldierCursor >= soldierIndices.len: break
                            let solIdx = soldierIndices[soldierCursor]
                            game.units[solIdx].assignedEmplacement = emplIdx
                            game.units[solIdx].inTransportOf = emplIdx  # versteckt bis abgekoppelt
                            game.units[emplIdx].crewIndices.add(solIdx)
                            soldierCursor += 1
                        # unbesetzte Geschuetze spawnen neutral, auch wenn sie gezogen werden
                        if game.units[emplIdx].crewIndices.len == 0:
                            game.units[emplIdx].factionIndex = -1

                    # Restliche Soldaten in Transporter laden
                    for trIdx in transportIndices:
                        let maxP = game.units[trIdx].definition.maxPassengers
                        while game.units[trIdx].passengerIndices.len < maxP:
                            if soldierCursor >= soldierIndices.len: break
                            let solIdx = soldierIndices[soldierCursor]
                            if game.units[solIdx].assignedEmplacement >= 0:
                                soldierCursor += 1
                                continue
                            game.units[solIdx].inTransportOf = trIdx
                            game.units[trIdx].passengerIndices.add(solIdx)
                            soldierCursor += 1

                    game.factions[factionIdx].troopSpawnQueue.delete(t)
                else:
                    t += 1

    block UPDATE_BURNING_DEBRIS:
        let deltaTime = getFrameTime()
        for i in 0 ..< game.debris.len:
            if game.debris[i].burnTimer > 0:
                game.debris[i].burnTimer -= deltaTime
                game.debris[i].fireAnimTimer -= deltaTime
                if game.debris[i].fireAnimTimer <= 0:
                    game.debris[i].fireFrame = (game.debris[i].fireFrame + 1) mod 4
                    game.debris[i].fireAnimTimer = 0.25
                if game.debris[i].burnTimer < 0:
                    game.debris[i].burnTimer = 0

    block UPDATE_EFFECTS:
        let deltaTime = getFrameTime()
        for i in 0 ..< game.effects.len:
            game.effects[i].timer -= deltaTime
        var j = 0
        while j < game.effects.len:
            if game.effects[j].timer <= 0:
                game.effects.delete(j)
            else:
                j += 1

    block UPDATE_SMOKE:
        let deltaTime = getFrameTime()
        for i in 0 ..< game.smokeParticles.len:
            game.smokeParticles[i].position.x += game.smokeParticles[i].velocity.x * deltaTime
            game.smokeParticles[i].position.y += game.smokeParticles[i].velocity.y * deltaTime
            game.smokeParticles[i].velocity.x *= 0.98
            game.smokeParticles[i].velocity.y *= 0.98
            game.smokeParticles[i].radius += 3.0 * deltaTime  # wird groesser beim wegdriften
            game.smokeParticles[i].timer -= deltaTime
        var j = 0
        while j < game.smokeParticles.len:
            if game.smokeParticles[j].timer <= 0:
                game.smokeParticles.delete(j)
            else:
                j += 1

    block UPDATE_CHUNK_KRAFT_TICK:
        game.kraftTickTimer += getFrameTime()
        if game.kraftTickTimer >= 1.0:
            game.kraftTickTimer -= 1.0
            for i in 0 ..< game.map.chunks.len:
                if game.map.chunks[i].kraftPerSecond <= 0: continue
                let owner = game.map.chunks[i].currentOwner
                if owner < 0: continue
                game.factions[owner].kraft += game.map.chunks[i].kraftPerSecond

    block UPDATE_VICTORY:
        if game.gameOver: break UPDATE_VICTORY
        for factionIdx in 0 ..< game.factions.len:
            if game.factions[factionIdx].defeated: continue
            var holdsSpawn = false
            for ci in 0 ..< game.map.chunks.len:
                if game.map.chunks[ci].spawnForFaction == factionIdx and
                   game.map.chunks[ci].currentOwner == factionIdx:
                    holdsSpawn = true
                    break
            if not holdsSpawn:
                game.factions[factionIdx].defeated = true
        var aliveCount = 0
        var lastAlive = -1
        for factionIdx in 0 ..< game.factions.len:
            if not game.factions[factionIdx].defeated:
                aliveCount += 1
                lastAlive = factionIdx
        if aliveCount == 1:
            game.gameOver = true
            game.winnerFactionIndex = lastAlive
        elif aliveCount == 0:
            game.gameOver = true
            game.winnerFactionIndex = -1

