import std/math
import std/options
import std/random

import raylib

import types

proc updateCombat*(game: var GameState) =
    let chunkSizePixels = game.map.chunkSizePixels
    let mapSizePixels = game.map.mapSizePixels

    block UPDATE_COMBAT:
        let deltaTime = getFrameTime()
        let chunksPerSide = game.map.mapSizeInChunks
        for i in 0 ..< game.units.len:
            if not game.units[i].alive: continue
            if game.units[i].inBuilding < 0 and game.units[i].inTransportOf >= 0: continue
            if game.units[i].factionIndex < 0: continue  # neutrale Units schiessen nicht
            if game.units[i].assignedEmplacement >= 0: continue  # Crew-Soldat schiesst nicht selbst
            # Emplacement braucht volle Crew zum Schiessen
            if game.units[i].definition.isEmplacement:
                if game.units[i].crewIndices.len < game.units[i].definition.crewSlots:
                    echo "DEBUG ART [", i, "] ", game.units[i].definition.name, " crew=", game.units[i].crewIndices.len, "/", game.units[i].definition.crewSlots, " -> zu wenig Crew"
                    continue
                # Pruefen ob alle Crew-Soldaten wirklich angekommen sind (assignedEmplacement gesetzt)
                var allArrived = true
                for crewIdx in game.units[i].crewIndices:
                    if game.units[crewIdx].targetPosition.isSome:
                        allArrived = false
                        echo "DEBUG ART [", i, "] crew[", crewIdx, "] noch unterwegs"
                        break
                if not allArrived: continue
            game.units[i].attackTimer -= deltaTime
            if game.units[i].grenadeCooldownTimer > 0:
                game.units[i].grenadeCooldownTimer -= deltaTime

            block TRY_GRENADE:
                let gdi = game.units[i].definition.grenadeDefIndex
                if gdi < 0: break TRY_GRENADE
                if game.units[i].grenadeAmmo <= 0: break TRY_GRENADE
                if game.units[i].grenadeCooldownTimer > 0: break TRY_GRENADE
                if game.units[i].inBuilding >= 0: break TRY_GRENADE  # im Bunker keine Granaten
                let gdef = game.grenadeDefs[gdi]
                let myPos = game.units[i].position
                let myFac = game.units[i].factionIndex
                let myChunkIdx2 = game.units[i].currentChunk
                let myChunkX2 = myChunkIdx2 div chunksPerSide
                let myChunkY2 = myChunkIdx2 mod chunksPerSide
                var targetIdx = -1
                var targetDist = float.high
                let gSearchRadius = max(1, (gdef.range / chunkSizePixels.float).int + 1)
                for dx in -gSearchRadius..gSearchRadius:
                    for dy in -gSearchRadius..gSearchRadius:
                        let ncX = myChunkX2 + dx
                        let ncY = myChunkY2 + dy
                        if ncX < 0 or ncY < 0 or ncX >= chunksPerSide or ncY >= chunksPerSide: continue
                        let nIdx = ncX * chunksPerSide + ncY
                        for eIdx in game.map.chunks[nIdx].unitIndices:
                            if not game.units[eIdx].alive: continue
                            if game.units[eIdx].factionIndex < 0: continue
                            if game.units[eIdx].factionIndex == myFac: continue
                            if game.units[eIdx].definition.damageCategory != gdef.targetCategory: continue
                            let edx = game.units[eIdx].position.x - myPos.x
                            let edy = game.units[eIdx].position.y - myPos.y
                            let edist = sqrt(edx * edx + edy * edy)
                            if edist <= gdef.range and edist < targetDist:
                                targetDist = edist
                                targetIdx = eIdx
                if targetIdx < 0: break TRY_GRENADE
                game.grenades.add(Grenade(
                    defIndex: gdi,
                    position: myPos,
                    startPosition: myPos,
                    targetPosition: game.units[targetIdx].position,
                    flightProgress: 0.0,
                    fuseTimer: gdef.fuseTimer,
                    landed: false,
                    thrownByFaction: myFac,
                    alive: true
                ))
                game.units[i].grenadeAmmo -= 1
                game.units[i].grenadeCooldownTimer = gdef.cooldown
                game.units[i].shootPauseTimer = 0.5
                continue

            if game.units[i].attackTimer > 0: continue
            let myFaction = game.units[i].factionIndex
            let inBuildingIdx = game.units[i].inBuilding
            let myPosition = if inBuildingIdx >= 0: game.buildings[inBuildingIdx].position
                             else: game.units[i].position
            let rangeMult = if inBuildingIdx >= 0: 1.5 else: 1.0
            let myRange = game.units[i].definition.attackRange * rangeMult
            let myDamageCategory = game.units[i].definition.damageCategory
            let myChunkIdx = if inBuildingIdx >= 0: game.buildings[inBuildingIdx].currentChunk
                             else: game.units[i].currentChunk
            let myChunkX = myChunkIdx div chunksPerSide
            let myChunkY = myChunkIdx mod chunksPerSide
            var bestIdx = -1
            var bestDist = float.high
            var bestIsBuilding = false
            let searchRadius = max(1, (myRange / chunkSizePixels.float).int + 1)
            for dx in -searchRadius..searchRadius:
                for dy in -searchRadius..searchRadius:
                    let neighborChunkX = myChunkX + dx
                    let neighborChunkY = myChunkY + dy
                    if neighborChunkX < 0 or neighborChunkY < 0 or neighborChunkX >= chunksPerSide or neighborChunkY >= chunksPerSide: continue
                    let neighborIdx = neighborChunkX * chunksPerSide + neighborChunkY
                    for enemyIdx in game.map.chunks[neighborIdx].unitIndices:
                        if not game.units[enemyIdx].alive: continue
                        if game.units[enemyIdx].factionIndex < 0: continue  # neutrale nicht beschiessen
                        if game.units[enemyIdx].factionIndex == myFaction: continue
                        let enemyDamageCategory = game.units[enemyIdx].definition.damageCategory
                        if myDamageCategory == DamageCategory.Light and enemyDamageCategory != DamageCategory.Light: continue
                        if myDamageCategory == DamageCategory.Medium and enemyDamageCategory == DamageCategory.Heavy: continue
                        let enemyDeltaX = game.units[enemyIdx].position.x - myPosition.x
                        let enemyDeltaY = game.units[enemyIdx].position.y - myPosition.y
                        let enemyDistance = sqrt(enemyDeltaX * enemyDeltaX + enemyDeltaY * enemyDeltaY)
                        if enemyDistance <= myRange and enemyDistance < bestDist:
                            bestDist = enemyDistance
                            bestIdx = enemyIdx
                            bestIsBuilding = false
            block SEARCH_BUILDINGS:
                if myDamageCategory == DamageCategory.Light: break SEARCH_BUILDINGS
                for bi in 0 ..< game.buildings.len:
                    if not game.buildings[bi].alive: continue
                    if game.buildings[bi].factionIndex < 0: continue
                    if game.buildings[bi].factionIndex == myFaction: continue
                    let bDeltaX = game.buildings[bi].position.x - myPosition.x
                    let bDeltaY = game.buildings[bi].position.y - myPosition.y
                    let bDist = sqrt(bDeltaX * bDeltaX + bDeltaY * bDeltaY)
                    if bDist <= myRange and bDist < bestDist:
                        bestDist = bDist
                        bestIdx = bi
                        bestIsBuilding = true
            if bestIdx >= 0:
                if game.units[i].definition.isEmplacement:
                    echo "DEBUG ART [", i, "] SCHIESST auf [", bestIdx, "] dist=", bestDist
                let targetPos = if bestIsBuilding: game.buildings[bestIdx].position
                                else: game.units[bestIdx].position
                let aimDx = targetPos.x - myPosition.x
                let aimDy = targetPos.y - myPosition.y
                game.units[i].rotation = arctan2(aimDx, -aimDy) * 180.0 / PI
                # sourceDefIndex: finde den richtigen UnitDef-Index fuer Explosions-Radien
                var srcDefIdx = 0
                for di in 0 ..< game.unitDefs.len:
                    if game.unitDefs[di].name == game.units[i].definition.name:
                        srcDefIdx = di
                        break
                game.projectiles.add(Projectile(
                    position: myPosition,
                    targetPosition: targetPos,
                    speed: 8.0,
                    damage: game.units[i].definition.attackDamage,
                    sourceDefIndex: srcDefIdx,
                    alive: true
                ))
                if bestIsBuilding:
                    game.buildings[bestIdx].health -= game.units[i].definition.attackDamage
                game.units[i].attackTimer = game.units[i].definition.attackCooldown
                if inBuildingIdx < 0:
                    game.units[i].shootPauseTimer = 0.8
            else:
                if game.units[i].definition.isEmplacement:
                    echo "DEBUG ART [", i, "] kein Ziel gefunden, pos=", game.units[i].position, " range=", myRange, " faction=", myFaction, " searchRadius=", searchRadius

    block UPDATE_PROJECTILES:
        for i in 0 ..< game.projectiles.len:
            if not game.projectiles[i].alive: continue
            let dx = game.projectiles[i].targetPosition.x - game.projectiles[i].position.x
            let dy = game.projectiles[i].targetPosition.y - game.projectiles[i].position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist <= game.projectiles[i].speed:
                let impactPosition = game.projectiles[i].targetPosition
                let sourceDefIndex = game.projectiles[i].sourceDefIndex
                let sourceDefinition = game.unitDefs[sourceDefIndex]
                game.explosions.add(Explosion(
                    position: impactPosition,
                    radiusHeavy: sourceDefinition.explosionRadiusHeavy,
                    radiusMedium: sourceDefinition.explosionRadiusMedium,
                    radiusLight: sourceDefinition.explosionRadiusLight,
                    damage: game.projectiles[i].damage,
                    currentRadius: 0,
                    timer: 0.4,
                    maxTimer: 0.4,
                    damageApplied: false
                ))
                game.projectiles[i].alive = false
            else:
                game.projectiles[i].position.x += dx / dist * game.projectiles[i].speed
                game.projectiles[i].position.y += dy / dist * game.projectiles[i].speed
        var j = 0
        while j < game.projectiles.len:
            if not game.projectiles[j].alive:
                game.projectiles.delete(j)
            else:
                j += 1

    block UPDATE_GRENADES:
        let deltaTime = getFrameTime()
        for i in 0 ..< game.grenades.len:
            if not game.grenades[i].alive: continue
            let gdef = game.grenadeDefs[game.grenades[i].defIndex]
            if not game.grenades[i].landed:
                game.grenades[i].flightProgress += deltaTime / gdef.flightDuration
                if game.grenades[i].flightProgress >= 1.0:
                    game.grenades[i].flightProgress = 1.0
                    game.grenades[i].landed = true
                    game.grenades[i].position = game.grenades[i].targetPosition
                else:
                    let p = game.grenades[i].flightProgress
                    game.grenades[i].position.x = game.grenades[i].startPosition.x +
                        (game.grenades[i].targetPosition.x - game.grenades[i].startPosition.x) * p
                    game.grenades[i].position.y = game.grenades[i].startPosition.y +
                        (game.grenades[i].targetPosition.y - game.grenades[i].startPosition.y) * p
            else:
                game.grenades[i].fuseTimer -= deltaTime
                if game.grenades[i].fuseTimer <= 0:
                    game.explosions.add(Explosion(
                        position: game.grenades[i].position,
                        radiusHeavy: gdef.explosionRadiusHeavy,
                        radiusMedium: gdef.explosionRadiusMedium,
                        radiusLight: gdef.explosionRadiusLight,
                        damage: gdef.damage,
                        currentRadius: 0,
                        timer: 0.4,
                        maxTimer: 0.4,
                        damageApplied: false
                    ))
                    game.grenades[i].alive = false
        var gj = 0
        while gj < game.grenades.len:
            if not game.grenades[gj].alive:
                game.grenades.delete(gj)
            else:
                gj += 1

    block UPDATE_EXPLOSIONS:
        let deltaTime = getFrameTime()
        let chunksPerSide = game.map.mapSizeInChunks
        for i in 0 ..< game.explosions.len:
            if not game.explosions[i].damageApplied:
                game.explosions[i].damageApplied = true
                let fireRadius = game.explosions[i].radiusLight * 0.6
                game.effects.add(Effect(
                    position: game.explosions[i].position,
                    radius: fireRadius,
                    timer: 1.5 + rand(1.0),
                    maxTimer: 2.5
                ))
                if game.explosions[i].radiusHeavy > 0:
                    game.debris.add(Debris(
                        position: game.explosions[i].position,
                        visualKind: VisualKind.Sprite,
                        radius: game.explosions[i].radiusHeavy * 0.25,
                        rotation: rand(0.0 .. 360.0),
                        textureKey: "hole"
                    ))
                let smokeOrigin = game.explosions[i].position
                for _ in 0 ..< 6:
                    let angle = rand(0.0 .. 2.0 * PI)
                    let speed = rand(8.0 .. 25.0)
                    let life = 3.0 + rand(3.0)
                    game.smokeParticles.add(SmokeParticle(
                        position: Vector2(
                            x: smokeOrigin.x + rand(-5.0..5.0),
                            y: smokeOrigin.y + rand(-5.0..5.0)
                        ),
                        velocity: Vector2(x: cos(angle) * speed, y: sin(angle) * speed),
                        radius: rand(4.0 .. 10.0),
                        timer: life,
                        maxTimer: life
                    ))
                let explosionPos = game.explosions[i].position
                let radiusLight = game.explosions[i].radiusLight
                let radiusMedium = game.explosions[i].radiusMedium
                let radiusHeavy = game.explosions[i].radiusHeavy
                let baseDamage = game.explosions[i].damage
                let explosionChunkX = clamp(explosionPos.x.int, 0, mapSizePixels - 1) div chunkSizePixels
                let explosionChunkY = clamp(explosionPos.y.int, 0, mapSizePixels - 1) div chunkSizePixels
                for dx in -2..2:
                    for dy in -2..2:
                        let neighborChunkX = explosionChunkX + dx
                        let neighborChunkY = explosionChunkY + dy
                        if neighborChunkX < 0 or neighborChunkY < 0 or neighborChunkX >= chunksPerSide or neighborChunkY >= chunksPerSide: continue
                        let neighborIdx = neighborChunkX * chunksPerSide + neighborChunkY
                        for unitIdx in game.map.chunks[neighborIdx].unitIndices:
                            if not game.units[unitIdx].alive: continue
                            let unitDeltaX = game.units[unitIdx].position.x - explosionPos.x
                            let unitDeltaY = game.units[unitIdx].position.y - explosionPos.y
                            let unitDistance = sqrt(unitDeltaX * unitDeltaX + unitDeltaY * unitDeltaY)
                            let unitDamageCategory = game.units[unitIdx].definition.damageCategory
                            var damage = 0
                            if radiusHeavy > 0 and unitDistance <= radiusHeavy:
                                damage = baseDamage
                            elif radiusMedium > 0 and unitDistance <= radiusMedium:
                                if unitDamageCategory != DamageCategory.Heavy:
                                    damage = (baseDamage.float * 0.6).int
                            elif radiusLight > 0 and unitDistance <= radiusLight:
                                if unitDamageCategory == DamageCategory.Light:
                                    damage = (baseDamage.float * 0.3).int
                            if damage > 0:
                                let armor = game.units[unitIdx].definition.baseArmor
                                let finalDamage = max(1, damage - armor)
                                game.units[unitIdx].health -= finalDamage
                                if game.units[unitIdx].health <= 0:
                                    game.units[unitIdx].alive = false
                                    let deadUnit = game.units[unitIdx]
                                    let deadTexKey = deadUnit.definition.deadTexturePath
                                    let burns = deadUnit.definition.damageCategory in {DamageCategory.Heavy, DamageCategory.Medium}
                                    game.debris.add(Debris(
                                        position: deadUnit.position,
                                        visualKind: deadUnit.definition.visualKind,
                                        radius: deadUnit.definition.radius,
                                        width: deadUnit.definition.width,
                                        height: deadUnit.definition.height,
                                        rotation: rand(0.0 .. 360.0),
                                        textureKey: deadTexKey,
                                        burnTimer: if burns: 60.0 else: 0.0
                                    ))

            game.explosions[i].timer -= deltaTime
            if game.explosions[i].radiusLight > 0:
                let progress = 1.0 - game.explosions[i].timer / game.explosions[i].maxTimer
                game.explosions[i].currentRadius = game.explosions[i].radiusLight * progress
        var j = 0
        while j < game.explosions.len:
            if game.explosions[j].timer <= 0:
                game.explosions.delete(j)
            else:
                j += 1
