import std/math
import std/random
import std/options
import raylib

import ../shared/types
import pathfinding

const AI_SPAWN_INTERVAL = 4.0
const AI_THINK_INTERVAL = 2.0
const CHUNK_UNIT_SOFT_CAP = 5     # wieviele Units pro Chunk als Verteidigung reichen
const STALE_TIME_MIN = 60.0       # ab wann idle Units als stale gelten
const STALE_TIME_MAX = 180.0      # maximale idle-Zeit bevor forced reassign

# -- Hilfsfunktionen --

proc sendUnitToChunk(game: var GameState, unitIdx: int, targetChunkIdx: int) =
    let chunkSizePixels = game.map.chunkSizePixels
    let unitChunk = game.units[unitIdx].currentChunk
    if unitChunk == targetChunkIdx: return
    let path = game.findPath(unitChunk, targetChunkIdx)
    if path.len == 0: return
    let targetChunk = game.map.chunks[targetChunkIdx]
    let margin = 20.0
    let finalPos = Vector2(
        x: targetChunk.x.float + margin + rand(chunkSizePixels.float - 2 * margin),
        y: targetChunk.y.float + margin + rand(chunkSizePixels.float - 2 * margin)
    )
    game.units[unitIdx].path = path
    game.units[unitIdx].finalPosition = some(finalPos)
    game.units[unitIdx].idleTimer = 0
    if path.len > 1:
        let nextChunk = game.map.chunks[path[0]]
        let half = chunkSizePixels.float / 2.0
        game.units[unitIdx].targetPosition = some(Vector2(x: nextChunk.x.float + half, y: nextChunk.y.float + half))
    else:
        game.units[unitIdx].targetPosition = some(finalPos)

proc isUnitInCombat(game: GameState, unitIdx: int): bool =
    let myPos = game.units[unitIdx].position
    let myRange = game.units[unitIdx].definition.attackRange
    let myFaction = game.units[unitIdx].factionIndex
    let chunksPerSide = game.map.mapSizeInChunks
    let myChunk = game.units[unitIdx].currentChunk
    let myChunkX = myChunk div chunksPerSide
    let myChunkY = myChunk mod chunksPerSide
    for dx in -1..1:
        for dy in -1..1:
            let nx = myChunkX + dx
            let ny = myChunkY + dy
            if nx < 0 or ny < 0 or nx >= chunksPerSide or ny >= chunksPerSide: continue
            let neighborIdx = nx * chunksPerSide + ny
            for ui in game.map.chunks[neighborIdx].unitIndices:
                if not game.units[ui].alive: continue
                if game.units[ui].factionIndex == myFaction: continue
                let ex = game.units[ui].position.x - myPos.x
                let ey = game.units[ui].position.y - myPos.y
                if sqrt(ex * ex + ey * ey) <= myRange * 1.5:
                    return true

proc chunkDist(game: GameState, a, b: int): float =
    let chunksPerSide = game.map.mapSizeInChunks
    let ax = a div chunksPerSide
    let ay = a mod chunksPerSide
    let bx = b div chunksPerSide
    let by = b mod chunksPerSide
    abs(ax - bx).float + abs(ay - by).float

proc countFactionUnits(game: GameState, factionIdx: int): int =
    for i in 0 ..< game.units.len:
        if game.units[i].alive and game.units[i].inTransportOf < 0 and game.units[i].factionIndex == factionIdx:
            result += 1

proc countEnemyUnits(game: GameState, factionIdx: int): int =
    for i in 0 ..< game.units.len:
        if game.units[i].alive and game.units[i].inTransportOf < 0 and game.units[i].factionIndex != factionIdx:
            result += 1

proc countFactionUnitsOnChunk(game: GameState, chunkIdx: int, factionIdx: int): int =
    for ui in game.map.chunks[chunkIdx].unitIndices:
        if game.units[ui].alive and game.units[ui].factionIndex == factionIdx:
            result += 1

proc countEnemyUnitsOnChunk(game: GameState, chunkIdx: int, factionIdx: int): int =
    for ui in game.map.chunks[chunkIdx].unitIndices:
        if game.units[ui].alive and game.units[ui].factionIndex != factionIdx:
            result += 1

proc findSpawnChunks(game: GameState, factionIdx: int): seq[int] =
    for i in 0 ..< game.map.chunks.len:
        if game.map.chunks[i].spawnForFaction == factionIdx:
            result.add(i)

proc findEnemySpawnChunks(game: GameState, factionIdx: int): seq[int] =
    for i in 0 ..< game.map.chunks.len:
        if game.map.chunks[i].spawnForFaction >= 0 and game.map.chunks[i].spawnForFaction != factionIdx:
            result.add(i)

proc isSpawnThreatened(game: GameState, factionIdx: int): bool =
    let chunksPerSide = game.map.mapSizeInChunks
    for spawnChunk in game.findSpawnChunks(factionIdx):
        let sx = spawnChunk div chunksPerSide
        let sy = spawnChunk mod chunksPerSide
        for dx in -2..2:
            for dy in -2..2:
                let nx = sx + dx
                let ny = sy + dy
                if nx < 0 or ny < 0 or nx >= chunksPerSide or ny >= chunksPerSide: continue
                let neighborIdx = nx * chunksPerSide + ny
                if game.countEnemyUnitsOnChunk(neighborIdx, factionIdx) > 0:
                    return true

proc getAllAvailableUnits(game: GameState, factionIdx: int): seq[int] =
    ## Idle + stale Units (stale werden auch verfuegbar gemacht)
    for i in 0 ..< game.units.len:
        if not game.units[i].alive: continue
        if game.units[i].inTransportOf >= 0: continue
        if game.units[i].factionIndex != factionIdx: continue
        if game.isUnitInCombat(i): continue
        if game.units[i].targetPosition.isNone:
            result.add(i)

proc findFrontChunks(game: GameState, factionIdx: int): seq[int] =
    let chunksPerSide = game.map.mapSizeInChunks
    for i in 0 ..< game.map.chunks.len:
        if not game.map.chunks[i].passable: continue
        if game.map.chunks[i].currentOwner != factionIdx: continue
        let chunkX = i div chunksPerSide
        let chunkY = i mod chunksPerSide
        var isFront = false
        for dx in -1..1:
            for dy in -1..1:
                if dx == 0 and dy == 0: continue
                let nx = chunkX + dx
                let ny = chunkY + dy
                if nx < 0 or ny < 0 or nx >= chunksPerSide or ny >= chunksPerSide: continue
                let neighborIdx = nx * chunksPerSide + ny
                if not game.map.chunks[neighborIdx].passable: continue
                if game.map.chunks[neighborIdx].currentOwner != factionIdx:
                    isFront = true
                    break
            if isFront: break
        if isFront:
            result.add(i)

proc findAttackTargets(game: GameState, factionIdx: int): seq[int] =
    ## Nicht-eigene passable Chunks die an eigene Chunks oder eigene Units grenzen
    let chunksPerSide = game.map.mapSizeInChunks
    for i in 0 ..< game.map.chunks.len:
        if not game.map.chunks[i].passable: continue
        if game.map.chunks[i].currentOwner == factionIdx: continue
        let chunkX = i div chunksPerSide
        let chunkY = i mod chunksPerSide
        var relevant = false
        for dx in -1..1:
            for dy in -1..1:
                if dx == 0 and dy == 0: continue
                let nx = chunkX + dx
                let ny = chunkY + dy
                if nx < 0 or ny < 0 or nx >= chunksPerSide or ny >= chunksPerSide: continue
                let neighborIdx = nx * chunksPerSide + ny
                if game.map.chunks[neighborIdx].currentOwner == factionIdx:
                    relevant = true
                    break
                if game.countFactionUnitsOnChunk(neighborIdx, factionIdx) > 0:
                    relevant = true
                    break
            if relevant: break
        if relevant:
            result.add(i)

proc sendNearestUnit(game: var GameState, units: var seq[int], targetChunk: int) =
    ## Schickt die naechste Unit aus der Liste zum Ziel und entfernt sie aus der Liste
    if units.len == 0: return
    var bestIdx = -1
    var bestDist = float.high
    for j in 0 ..< units.len:
        let dist = game.chunkDist(game.units[units[j]].currentChunk, targetChunk)
        if dist < bestDist:
            bestDist = dist
            bestIdx = j
    if bestIdx >= 0:
        game.sendUnitToChunk(units[bestIdx], targetChunk)
        units.delete(bestIdx)

proc sendNUnitsToChunk(game: var GameState, units: var seq[int], targetChunk: int, n: int) =
    for _ in 0 ..< n:
        if units.len == 0: break
        game.sendNearestUnit(units, targetChunk)

# -- Strategie-Procs --

proc strategyLastStand(game: var GameState, factionIdx: int) =
    ## Alles zum Spawn zurueckziehen
    var units = game.getAllAvailableUnits(factionIdx)
    let spawnChunks = game.findSpawnChunks(factionIdx)
    if spawnChunks.len == 0: return
    for ui in units:
        let nearest = block:
            var best = spawnChunks[0]
            var bestDist = game.chunkDist(game.units[ui].currentChunk, spawnChunks[0])
            for sc in spawnChunks:
                let d = game.chunkDist(game.units[ui].currentChunk, sc)
                if d < bestDist:
                    bestDist = d
                    best = sc
            best
        game.sendUnitToChunk(ui, nearest)

proc strategyAllInAttack(game: var GameState, factionIdx: int) =
    ## Alle Units zum Feind, kein Halten
    var units = game.getAllAvailableUnits(factionIdx)
    let enemySpawns = game.findEnemySpawnChunks(factionIdx)
    let targets = game.findAttackTargets(factionIdx)
    # Jede Unit zum naechsten Angriffsziel oder feindlichen Spawn
    for ui in units:
        var bestChunk = -1
        var bestDist = float.high
        for t in targets:
            let d = game.chunkDist(game.units[ui].currentChunk, t)
            if d < bestDist:
                bestDist = d
                bestChunk = t
        for es in enemySpawns:
            let d = game.chunkDist(game.units[ui].currentChunk, es)
            if d < bestDist:
                bestDist = d
                bestChunk = es
        if bestChunk >= 0:
            game.sendUnitToChunk(ui, bestChunk)

proc strategyFrontline(game: var GameState, factionIdx: int) =
    ## Defensive Linie aufbauen, Chunks mit bis zu CHUNK_UNIT_SOFT_CAP besetzen
    var units = game.getAllAvailableUnits(factionIdx)
    let frontChunks = game.findFrontChunks(factionIdx)
    if frontChunks.len == 0:
        # Kein eigenes Territorium — Attack-Targets direkt angehen
        let targets = game.findAttackTargets(factionIdx)
        for ui in units:
            var bestChunk = -1
            var bestDist = float.high
            for t in targets:
                let d = game.chunkDist(game.units[ui].currentChunk, t)
                if d < bestDist:
                    bestDist = d
                    bestChunk = t
            if bestChunk >= 0:
                game.sendUnitToChunk(ui, bestChunk)
        return

    # Front-Chunks auffuellen bis Soft-Cap
    for fc in frontChunks:
        let current = game.countFactionUnitsOnChunk(fc, factionIdx)
        let need = max(0, CHUNK_UNIT_SOFT_CAP - current)
        if need > 0:
            game.sendNUnitsToChunk(units, fc, need)

proc strategyOneAttackGroup(game: var GameState, factionIdx: int) =
    ## Frontline halten + eine Angriffsgruppe zum besten Ziel
    var units = game.getAllAvailableUnits(factionIdx)
    let frontChunks = game.findFrontChunks(factionIdx)
    let targets = game.findAttackTargets(factionIdx)

    # Erst Front auffuellen
    for fc in frontChunks:
        let current = game.countFactionUnitsOnChunk(fc, factionIdx)
        let need = max(0, CHUNK_UNIT_SOFT_CAP - current)
        if need > 0:
            game.sendNUnitsToChunk(units, fc, need)

    # Rest als Angriffsgruppe zum schwächsten Ziel
    if units.len > 0 and targets.len > 0:
        var bestTarget = targets[0]
        var leastDefenders = int.high
        for t in targets:
            let defenders = game.countEnemyUnitsOnChunk(t, factionIdx)
            if defenders < leastDefenders:
                leastDefenders = defenders
                bestTarget = t
        for ui in units:
            game.sendUnitToChunk(ui, bestTarget)

proc strategyTwoAttackGroups(game: var GameState, factionIdx: int) =
    ## Frontline halten + zwei Angriffsgruppen zu verschiedenen Zielen
    var units = game.getAllAvailableUnits(factionIdx)
    let frontChunks = game.findFrontChunks(factionIdx)
    let targets = game.findAttackTargets(factionIdx)

    # Erst Front auffuellen
    for fc in frontChunks:
        let current = game.countFactionUnitsOnChunk(fc, factionIdx)
        let need = max(0, CHUNK_UNIT_SOFT_CAP - current)
        if need > 0:
            game.sendNUnitsToChunk(units, fc, need)

    if units.len < 2 or targets.len == 0: return

    # Zwei verschiedene Ziele waehlen (weit auseinander)
    var target1 = targets[0]
    var target2 = if targets.len > 1: targets[targets.len - 1] else: targets[0]
    # Versuche die am weitesten entfernten Ziele zu finden
    var maxDist = 0.0
    for i in 0 ..< targets.len:
        for j in (i + 1) ..< targets.len:
            let d = game.chunkDist(targets[i], targets[j])
            if d > maxDist:
                maxDist = d
                target1 = targets[i]
                target2 = targets[j]

    # Units aufteilen: jede Unit zum naechsten der beiden Ziele
    for ui in units:
        let d1 = game.chunkDist(game.units[ui].currentChunk, target1)
        let d2 = game.chunkDist(game.units[ui].currentChunk, target2)
        if d1 <= d2:
            game.sendUnitToChunk(ui, target1)
        else:
            game.sendUnitToChunk(ui, target2)

proc strategyProbing(game: var GameState, factionIdx: int) =
    ## Kleine Gruppen (2-3) zu verschiedenen Zielen schicken, Front halten
    var units = game.getAllAvailableUnits(factionIdx)
    let frontChunks = game.findFrontChunks(factionIdx)
    let targets = game.findAttackTargets(factionIdx)

    # Front minimal besetzen (weniger als normal)
    for fc in frontChunks:
        let current = game.countFactionUnitsOnChunk(fc, factionIdx)
        let need = max(0, 3 - current)  # nur 3 statt SOFT_CAP
        if need > 0:
            game.sendNUnitsToChunk(units, fc, need)

    # Rest in 2er/3er-Gruppen auf verschiedene Ziele verteilen
    if units.len == 0 or targets.len == 0: return
    var targetIdx = 0
    while units.len > 0:
        let groupSize = min(units.len, 2 + rand(1))  # 2 oder 3
        let target = targets[targetIdx mod targets.len]
        game.sendNUnitsToChunk(units, target, groupSize)
        targetIdx += 1

proc strategyFastControl(game: var GameState, factionIdx: int) =
    ## Einzelne Units ausschwärmen um moeglichst viele Chunks zu erobern
    var units = game.getAllAvailableUnits(factionIdx)
    let targets = game.findAttackTargets(factionIdx)
    if targets.len == 0: return

    # Jede Unit zu einem anderen Ziel (Round-Robin)
    var targetIdx = 0
    for ui in units:
        # Naechstes unbesetztes Ziel finden
        var bestTarget = targets[targetIdx mod targets.len]
        var bestDist = game.chunkDist(game.units[ui].currentChunk, bestTarget)
        # Schau ob ein naeheres Ziel da ist
        for t in targets:
            let d = game.chunkDist(game.units[ui].currentChunk, t)
            if d < bestDist and game.countFactionUnitsOnChunk(t, factionIdx) == 0:
                bestDist = d
                bestTarget = t
        game.sendUnitToChunk(ui, bestTarget)
        targetIdx += 1

proc strategyStosstrupp(game: var GameState, factionIdx: int) =
    ## Schnelle Einheiten zu einem strategisch wichtigen Ziel, Rest haelt Front
    var units = game.getAllAvailableUnits(factionIdx)
    let frontChunks = game.findFrontChunks(factionIdx)
    let enemySpawns = game.findEnemySpawnChunks(factionIdx)
    let targets = game.findAttackTargets(factionIdx)

    # Front halten
    for fc in frontChunks:
        let current = game.countFactionUnitsOnChunk(fc, factionIdx)
        let need = max(0, CHUNK_UNIT_SOFT_CAP - current)
        if need > 0:
            game.sendNUnitsToChunk(units, fc, need)

    if units.len == 0: return

    # Bestes Ziel: feindlicher Spawn oder hoechst-strategisches Ziel
    var bestTarget = -1
    if enemySpawns.len > 0:
        bestTarget = enemySpawns[0]
    elif targets.len > 0:
        bestTarget = targets[0]

    if bestTarget < 0: return

    # Schnellste Units zuerst als Stosstrupp losschicken
    # Sortierung ohne Closure: einfach die schnellsten N Units per Suche finden
    let groupSize = min(units.len, max(3, units.len div 2))
    var sent = 0
    var used: seq[int] = @[]
    while sent < groupSize and used.len < units.len:
        var bestIdx = -1
        var bestSpeed = -1.0
        for j in 0 ..< units.len:
            if j in used: continue
            if game.units[units[j]].definition.baseSpeed > bestSpeed:
                bestSpeed = game.units[units[j]].definition.baseSpeed
                bestIdx = j
        if bestIdx < 0: break
        game.sendUnitToChunk(units[bestIdx], bestTarget)
        used.add(bestIdx)
        sent += 1

# -- Strategie-Auswahl --

proc chooseStrategy(game: GameState, factionIdx: int): StrategyMode =
    let ownUnits = game.countFactionUnits(factionIdx)
    let enemyUnits = game.countEnemyUnits(factionIdx)
    let spawnThreatened = game.isSpawnThreatened(factionIdx)
    let frontChunks = game.findFrontChunks(factionIdx)
    let targets = game.findAttackTargets(factionIdx)

    # Spawn bedroht -> LastStand
    if spawnThreatened and ownUnits < 10:
        return StrategyMode.LastStand

    # Sehr wenige Units
    if ownUnits <= 3:
        return StrategyMode.FastControl

    # Wenig Units, Feind hat mehr
    if ownUnits < 8 and enemyUnits > ownUnits * 2:
        return StrategyMode.Probing

    # Deutliche Uebermacht -> All In
    if ownUnits > enemyUnits * 3 and enemyUnits > 0:
        return StrategyMode.AllInAttack

    # Gute Uebermacht -> zwei Angriffsgruppen
    if ownUnits > enemyUnits * 2 and ownUnits >= 12:
        return StrategyMode.TwoAttackGroups

    # Genuegend fuer Offensive
    if ownUnits >= 15 and frontChunks.len > 0:
        # Stosstrupp wenn wenig Targets direkt an der Front
        if targets.len <= 3:
            return StrategyMode.Stosstrupp
        return StrategyMode.OneAttackGroup

    # Genug fuer Frontline
    if ownUnits >= 8 and frontChunks.len > 0:
        return StrategyMode.Frontline

    # Feind hat wenig Praesenz -> schnell Chunks nehmen
    if enemyUnits < 5:
        return StrategyMode.FastControl

    # Default
    return StrategyMode.Frontline

# -- Spawning --

proc updateAISpawn(game: var GameState, factionIdx: int) =
    let deltaTime = getFrameTime()
    game.factions[factionIdx].aiSpawnTimer -= deltaTime
    if game.factions[factionIdx].aiSpawnTimer > 0: return
    game.factions[factionIdx].aiSpawnTimer = AI_SPAWN_INTERVAL

    var spawnChunk = -1
    for i in 0 ..< game.map.chunks.len:
        if game.map.chunks[i].spawnForFaction == factionIdx:
            spawnChunk = i
            break
    if spawnChunk < 0: return

    var defIdx = -1
    let roll = rand(1.0)
    let wantedName = if roll < 0.4: "RifleSoldier"
                     elif roll < 0.7: "MPSoldier"
                     else: "Tank"
    for i in 0 ..< game.unitDefs.len:
        if game.unitDefs[i].name == wantedName: defIdx = i; break
    if defIdx < 0: return

    if game.factions[factionIdx].kraft >= game.unitDefs[defIdx].kraftCost:
        game.factions[factionIdx].kraft -= game.unitDefs[defIdx].kraftCost
        game.factions[factionIdx].spawnQueue.add(SpawnRequest(
            unitDefIndex: defIdx,
            factionIndex: factionIdx,
            spawnChunkIndex: spawnChunk,
            timer: SPAWN_TIME
        ))

# -- Bunker-Besetzung --

proc aiOccupyBunkers(game: var GameState, factionIdx: int) =
    ## Eigene/neutrale Bunker mit idle Inf befuellen. Nahe Units werden direkt
    ## eingesogen, entfernte aber verfuegbare werden zum Bunker-Chunk geschickt.
    let loadRadius = 120.0
    let sendRadius = 6.0  # in Chunks — Units weiter weg ignorieren
    for b in 0 ..< game.buildings.len:
        if not game.buildings[b].alive: continue
        if game.buildings[b].kind != BuildingKind.Bunker: continue
        let bFaction = game.buildings[b].factionIndex
        if bFaction >= 0 and bFaction != factionIdx: continue
        let maxO = game.buildings[b].maxOccupants
        if game.buildings[b].occupantIndices.len >= maxO: continue
        let pos = game.buildings[b].position

        # Stufe 1: nahe Units direkt einsaugen
        for i in 0 ..< game.units.len:
            if game.buildings[b].occupantIndices.len >= maxO: break
            if not game.units[i].alive: continue
            if game.units[i].factionIndex != factionIdx: continue
            if game.units[i].inTransportOf >= 0: continue
            if game.units[i].inBuilding >= 0: continue
            if game.units[i].assignedEmplacement >= 0: continue
            if game.units[i].definition.canTransport: continue
            if game.units[i].definition.isEmplacement: continue
            if game.units[i].definition.damageCategory != DamageCategory.Light: continue
            let dx = game.units[i].position.x - pos.x
            let dy = game.units[i].position.y - pos.y
            if sqrt(dx * dx + dy * dy) > loadRadius: continue
            if game.buildings[b].factionIndex < 0:
                game.buildings[b].factionIndex = factionIdx
            game.units[i].inBuilding = b
            game.units[i].inTransportOf = b
            game.units[i].targetPosition = none(Vector2)
            game.units[i].finalPosition = none(Vector2)
            game.units[i].path = @[]
            game.buildings[b].occupantIndices.add(i)

        # Stufe 2: idle Units in der Naehe zum Bunker-Chunk schicken bis voll
        if game.buildings[b].occupantIndices.len >= maxO: continue
        var idle = game.getAllAvailableUnits(factionIdx)
        var sent = 0
        let needed = maxO - game.buildings[b].occupantIndices.len
        while sent < needed and idle.len > 0:
            var bestIdx = -1
            var bestDist = sendRadius
            for j in 0 ..< idle.len:
                let u = idle[j]
                if game.units[u].definition.canTransport: continue
                if game.units[u].definition.isEmplacement: continue
                if game.units[u].definition.damageCategory != DamageCategory.Light: continue
                let d = game.chunkDist(game.units[u].currentChunk, game.buildings[b].currentChunk)
                if d < bestDist:
                    bestDist = d
                    bestIdx = j
            if bestIdx < 0: break
            game.sendUnitToChunk(idle[bestIdx], game.buildings[b].currentChunk)
            idle.delete(bestIdx)
            sent += 1

# -- Stale-Reset --

proc resetStaleUnits(game: var GameState, factionIdx: int) =
    ## Stale Units werden verfuegbar gemacht indem ihr idleTimer zurueckgesetzt wird
    ## und ihr Ziel geloescht wird (damit die Strategie sie neu zuweisen kann)
    for i in 0 ..< game.units.len:
        if not game.units[i].alive: continue
        if game.units[i].factionIndex != factionIdx: continue
        if game.isUnitInCombat(i): continue
        if game.units[i].targetPosition.isSome: continue
        if game.units[i].idleTimer >= STALE_TIME_MAX:
            game.units[i].idleTimer = 0

# -- Haupt-Update --

proc updateAI*(game: var GameState) =
    let deltaTime = getFrameTime()
    for factionIdx in 0 ..< game.factions.len:
        if not game.factions[factionIdx].aiControlled: continue
        game.updateAISpawn(factionIdx)

        game.factions[factionIdx].aiThinkTimer -= deltaTime
        if game.factions[factionIdx].aiThinkTimer > 0: continue
        game.factions[factionIdx].aiThinkTimer = AI_THINK_INTERVAL

        game.resetStaleUnits(factionIdx)
        game.aiOccupyBunkers(factionIdx)

        let strategy = game.chooseStrategy(factionIdx)
        game.factions[factionIdx].activeStrategy = strategy

        case strategy:
        of StrategyMode.LastStand: game.strategyLastStand(factionIdx)
        of StrategyMode.AllInAttack: game.strategyAllInAttack(factionIdx)
        of StrategyMode.Frontline: game.strategyFrontline(factionIdx)
        of StrategyMode.OneAttackGroup: game.strategyOneAttackGroup(factionIdx)
        of StrategyMode.TwoAttackGroups: game.strategyTwoAttackGroups(factionIdx)
        of StrategyMode.Probing: game.strategyProbing(factionIdx)
        of StrategyMode.FastControl: game.strategyFastControl(factionIdx)
        of StrategyMode.Stosstrupp: game.strategyStosstrupp(factionIdx)
