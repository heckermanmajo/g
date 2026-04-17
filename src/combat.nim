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
            if game.units[i].inTransportOf >= 0: continue
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
            if game.units[i].attackTimer > 0: continue
            let myFaction = game.units[i].factionIndex
            let myPosition = game.units[i].position
            let myRange = game.units[i].definition.attackRange
            let myDamageCategory = game.units[i].definition.damageCategory
            let myChunkX = game.units[i].currentChunk div chunksPerSide
            let myChunkY = game.units[i].currentChunk mod chunksPerSide
            var bestIdx = -1
            var bestDist = float.high
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
            if bestIdx >= 0:
                if game.units[i].definition.isEmplacement:
                    echo "DEBUG ART [", i, "] SCHIESST auf [", bestIdx, "] dist=", bestDist
                let aimDx = game.units[bestIdx].position.x - myPosition.x
                let aimDy = game.units[bestIdx].position.y - myPosition.y
                game.units[i].rotation = arctan2(aimDx, -aimDy) * 180.0 / PI
                # sourceDefIndex: finde den richtigen UnitDef-Index fuer Explosions-Radien
                var srcDefIdx = 0
                for di in 0 ..< game.unitDefs.len:
                    if game.unitDefs[di].name == game.units[i].definition.name:
                        srcDefIdx = di
                        break
                game.projectiles.add(Projectile(
                    position: myPosition,
                    targetPosition: game.units[bestIdx].position,
                    speed: 8.0,
                    damage: game.units[i].definition.attackDamage,
                    sourceDefIndex: srcDefIdx,
                    alive: true
                ))
                game.units[i].attackTimer = game.units[i].definition.attackCooldown
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
