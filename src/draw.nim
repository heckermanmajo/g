import std/math
import std/tables

import raylib

import types

proc drawGame*(game: var GameState) =
    let chunkSizePixels = game.map.chunkSizePixels

    let zoom = game.camera.zoom
    let strategicMode = zoom < 0.25

    block DRAW_MAP:
        let dontDisplayTiles = zoom < 0.5

        let viewRect = Rectangle(
            x: game.camera.target.x - game.camera.offset.x / zoom,
            y: game.camera.target.y - game.camera.offset.y / zoom,
            width: getScreenWidth().float / zoom,
            height: getScreenHeight().float / zoom
        )

        clearBackground(BLACK)
        beginMode2D(game.camera)

        for chunk in game.map.chunks:
            let chunkRect = Rectangle(
                x: chunk.x.float, y: chunk.y.float,
                width: chunkSizePixels.float, height: chunkSizePixels.float
            )
            if not checkCollisionRecs(chunkRect, viewRect): continue

            if dontDisplayTiles:
                let chunkColor = case chunk.kind:
                    of ChunkKind.Mountain: Color(r: 100, g: 100, b: 100, a: 255)
                    of ChunkKind.Water: Color(r: 40, g: 80, b: 180, a: 255)
                    of ChunkKind.Grass, ChunkKind.Spawn: Color(r: 60, g: 120, b: 40, a: 255)
                drawRectangle(chunk.x.int32, chunk.y.int32,
                    chunkSizePixels.int32, chunkSizePixels.int32, chunkColor)

            if not dontDisplayTiles:
                case chunk.kind:
                of ChunkKind.Mountain:
                    for tile in chunk.tiles:
                        drawRectangle(tile.x.int32, tile.y.int32,
                            PIXELS_PER_TILE.int32, PIXELS_PER_TILE.int32,
                            Color(r: 100, g: 100, b: 100, a: 255))
                of ChunkKind.Water:
                    for tile in chunk.tiles:
                        drawRectangle(tile.x.int32, tile.y.int32,
                            PIXELS_PER_TILE.int32, PIXELS_PER_TILE.int32,
                            Color(r: 40, g: 80, b: 180, a: 255))
                of ChunkKind.Grass, ChunkKind.Spawn:
                    for tile in chunk.tiles:
                        let margin = 0.14
                        let marginX = game.textures[tile.textureKey].width.float * margin
                        let marginY = game.textures[tile.textureKey].height.float * margin
                        let source = Rectangle(
                            x: marginX, y: marginY,
                            width: game.textures[tile.textureKey].width.float - 2 * marginX,
                            height: game.textures[tile.textureKey].height.float - 2 * marginY
                        )
                        let dest = Rectangle(
                            x: tile.x.float, y: tile.y.float,
                            width: PIXELS_PER_TILE.float, height: PIXELS_PER_TILE.float
                        )
                        drawTexture(game.textures[tile.textureKey], source, dest, Vector2(x: 0, y: 0), 0, WHITE)

            block DRAW_CHUNK_OWNER:
                if chunk.currentOwner >= 0:
                    let ownerColor = game.factions[chunk.currentOwner].color
                    drawRectangle(chunk.x.int32, chunk.y.int32,
                        chunkSizePixels.int32, chunkSizePixels.int32,
                        Color(r: ownerColor.r, g: ownerColor.g, b: ownerColor.b, a: 30))

            drawRectangleLines(
                chunk.x.int32, chunk.y.int32,
                chunkSizePixels.int32, chunkSizePixels.int32,
                GRAY
            )

            block DRAW_SPAWN_BORDER:
                if chunk.kind != ChunkKind.Spawn: break DRAW_SPAWN_BORDER
                let borderColor = Color(r: 255, g: 200, b: 0, a: 200)
                let borderThickness = 3.int32
                drawRectangle(chunk.x.int32, chunk.y.int32, chunkSizePixels.int32, borderThickness, borderColor)
                drawRectangle(chunk.x.int32, (chunk.y + chunkSizePixels - borderThickness.int).int32, chunkSizePixels.int32, borderThickness, borderColor)
                drawRectangle(chunk.x.int32, chunk.y.int32, borderThickness, chunkSizePixels.int32, borderColor)
                drawRectangle((chunk.x + chunkSizePixels - borderThickness.int).int32, chunk.y.int32, borderThickness, chunkSizePixels.int32, borderColor)

            block DRAW_BONUS_BORDER:
                let hasOneShot = chunk.kraftBonusOnCapture > 0 and not chunk.kraftBonusClaimed
                let hasPerSec = chunk.kraftPerSecond > 0
                if not hasOneShot and not hasPerSec: break DRAW_BONUS_BORDER
                drawRectangleLines(
                    chunk.x.int32, chunk.y.int32,
                    chunkSizePixels.int32, chunkSizePixels.int32,
                    GOLD
                )

    block DRAW_DEBRIS:
        if strategicMode: break DRAW_DEBRIS
        let debrisColor = Color(r: 60, g: 60, b: 60, a: 180)
        for debrisItem in game.debris:
            case debrisItem.visualKind:
            of VisualKind.Circle, VisualKind.Sprite:
                if debrisItem.textureKey != "" and debrisItem.textureKey in game.textures:
                    let texPtr = addr game.textures[debrisItem.textureKey]
                    let drawSize = debrisItem.radius * 2
                    let texW = texPtr[].width.float
                    let texH = texPtr[].height.float
                    let scale = drawSize / max(texW, texH)
                    let destW = texW * scale
                    let destH = texH * scale
                    let source = Rectangle(x: 0, y: 0, width: texW, height: texH)
                    let origin = Vector2(x: destW / 2, y: destH / 2)
                    let dest = Rectangle(
                        x: debrisItem.position.x,
                        y: debrisItem.position.y,
                        width: destW, height: destH
                    )
                    drawTexture(texPtr[], source, dest, origin, debrisItem.rotation.float32, WHITE)
                else:
                    drawCircle(debrisItem.position.x.int32, debrisItem.position.y.int32, debrisItem.radius.float32, debrisColor)
            of VisualKind.Rect:
                drawRectangle(
                    (debrisItem.position.x - debrisItem.width / 2).int32,
                    (debrisItem.position.y - debrisItem.height / 2).int32,
                    debrisItem.width.int32, debrisItem.height.int32, debrisColor)
            block DRAW_FIRE:
                if debrisItem.burnTimer <= 0: break DRAW_FIRE
                let fireKey = if debrisItem.fireFrame mod 2 == 0: "fire1" else: "fire2"
                if fireKey notin game.textures: break DRAW_FIRE
                let fireTex = addr game.textures[fireKey]
                let fireSize = max(debrisItem.radius * 2, max(debrisItem.width, debrisItem.height)) * 0.4
                let fTexW = fireTex[].width.float
                let fTexH = fireTex[].height.float
                let fScale = fireSize / max(fTexW, fTexH)
                let fDestW = fTexW * fScale
                let fDestH = fTexH * fScale
                let fSource = Rectangle(x: 0, y: 0, width: fTexW, height: fTexH)
                let fOrigin = Vector2(x: fDestW / 2, y: fDestH / 2)
                let alpha = if debrisItem.burnTimer > 5.0: 255'u8
                            else: (255.0 * debrisItem.burnTimer / 5.0).uint8
                let fireRotation = [0.0, 90.0, 180.0, 270.0][debrisItem.fireFrame]
                let offsetX = [-3.0, 4.0, -2.0, 5.0][debrisItem.fireFrame]
                let offsetY = [-2.0, 3.0, 4.0, -3.0][debrisItem.fireFrame]
                let fDest = Rectangle(
                    x: debrisItem.position.x + offsetX,
                    y: debrisItem.position.y + offsetY,
                    width: fDestW, height: fDestH
                )
                drawTexture(fireTex[], fSource, fDest, fOrigin, fireRotation.float32, Color(r: 255, g: 255, b: 255, a: alpha))

    block DRAW_UNITS:
        for i in 0 ..< game.units.len:
            let unit = game.units[i]
            if not unit.alive: continue
            if unit.inTransportOf >= 0: continue
            let color = if unit.factionIndex >= 0: game.factions[unit.factionIndex].color
                        else: GRAY

            block SELECTION_RING:
                if i notin game.selectedUnits: break SELECTION_RING
                case unit.definition.visualKind:
                of VisualKind.Circle, VisualKind.Sprite:
                    drawCircleLines(unit.position.x.int32, unit.position.y.int32, (unit.definition.radius + 4).float32, YELLOW)
                of VisualKind.Rect:
                    drawRectangleLines(
                        (unit.position.x - unit.definition.width / 2 - 3).int32,
                        (unit.position.y - unit.definition.height / 2 - 3).int32,
                        (unit.definition.width + 6).int32, (unit.definition.height + 6).int32, YELLOW
                    )
                drawCircleLines(unit.position.x.int32, unit.position.y.int32, unit.definition.attackRange.float32, Color(r: 255, g: 255, b: 255, a: 80))

                block PASSENGER_DOTS:
                    let count = unit.passengerIndices.len
                    if count == 0: break PASSENGER_DOTS
                    let dotRadius = 4.0
                    let spacing = 10.0
                    let totalWidth = (count - 1).float * spacing
                    let startX = unit.position.x - totalWidth / 2.0
                    let y = unit.position.y + unit.definition.radius + 8.0
                    for k in 0 ..< count:
                        drawCircle((startX + k.float * spacing).int32, y.int32, dotRadius.float32, GREEN)

            block UNIT_SHAPE:
                case unit.definition.visualKind:
                of VisualKind.Circle:
                    drawCircle(unit.position.x.int32, unit.position.y.int32, unit.definition.radius.float32, color)
                of VisualKind.Rect:
                    drawRectangle(
                        (unit.position.x - unit.definition.width / 2).int32,
                        (unit.position.y - unit.definition.height / 2).int32,
                        unit.definition.width.int32, unit.definition.height.int32, color
                    )
                of VisualKind.Sprite:
                    let isNeutralEmplacement = unit.definition.isEmplacement and unit.crewIndices.len == 0
                    let texPath = if isNeutralEmplacement and unit.definition.texturePathNeutral != "": unit.definition.texturePathNeutral
                                  elif unit.factionIndex == 0: unit.definition.texturePathRed
                                  else: unit.definition.texturePathBlue
                    if texPath != "" and texPath in game.textures:
                        let texPtr = addr game.textures[texPath]
                        let drawSize = unit.definition.radius * 2
                        let texW = texPtr[].width.float
                        let texH = texPtr[].height.float
                        let scale = drawSize / max(texW, texH)
                        let destW = texW * scale
                        let destH = texH * scale
                        let source = Rectangle(x: 0, y: 0, width: texW, height: texH)
                        let origin = Vector2(x: destW / 2, y: destH / 2)
                        let dest = Rectangle(
                            x: unit.position.x,
                            y: unit.position.y,
                            width: destW, height: destH
                        )
                        drawTexture(texPtr[], source, dest, origin, unit.rotation.float32, WHITE)
                    else:
                        drawCircle(unit.position.x.int32, unit.position.y.int32, unit.definition.radius.float32, color)

            block HEALTH_BAR:
                if strategicMode: break HEALTH_BAR
                if unit.health >= unit.definition.baseHealth: break HEALTH_BAR
                let hpRatio = unit.health.float / unit.definition.baseHealth.float
                let barWidth = 20.0
                let barHeight = 3.0
                let barY = case unit.definition.visualKind:
                    of VisualKind.Circle, VisualKind.Sprite: unit.position.y - unit.definition.radius - 6
                    of VisualKind.Rect: unit.position.y - unit.definition.height / 2 - 6
                let barX = unit.position.x - barWidth / 2
                drawRectangle(barX.int32, barY.int32, barWidth.int32, barHeight.int32, DARKGRAY)
                let greenColor = Color(r: 0, g: 200, b: 0, a: 255)
                let redColor = Color(r: 200, g: 0, b: 0, a: 255)
                let hpColor = if hpRatio > 0.5: greenColor else: redColor
                drawRectangle(barX.int32, barY.int32, (barWidth * hpRatio).int32, barHeight.int32, hpColor)

    block DRAW_BUILDINGS:
        for building in game.buildings:
            if not building.alive: continue
            let w = 60.0
            let h = 60.0
            let bx = building.position.x - w / 2.0
            let by = building.position.y - h / 2.0
            drawRectangle(bx.int32, by.int32, w.int32, h.int32, Color(r: 110, g: 110, b: 110, a: 255))
            if building.factionIndex >= 0:
                let fc = game.factions[building.factionIndex].color
                drawRectangle(bx.int32, by.int32, w.int32, h.int32, Color(r: fc.r, g: fc.g, b: fc.b, a: 90))
            drawRectangleLines(bx.int32, by.int32, w.int32, h.int32, BLACK)
            block BUILDING_HEALTH_BAR:
                if building.health >= building.maxHealth: break BUILDING_HEALTH_BAR
                let hpRatio = building.health.float / building.maxHealth.float
                let barWidth = 40.0
                let barHeight = 4.0
                let barX = building.position.x - barWidth / 2.0
                let barY = building.position.y - h / 2.0 - 8.0
                drawRectangle(barX.int32, barY.int32, barWidth.int32, barHeight.int32, DARKGRAY)
                let greenColor = Color(r: 0, g: 200, b: 0, a: 255)
                let redColor = Color(r: 200, g: 0, b: 0, a: 255)
                let hpColor = if hpRatio > 0.5: greenColor else: redColor
                drawRectangle(barX.int32, barY.int32, (barWidth * hpRatio).int32, barHeight.int32, hpColor)

    block DRAW_PROJECTILES:
        if strategicMode: break DRAW_PROJECTILES
        for projectile in game.projectiles:
            if not projectile.alive: continue
            drawCircle(projectile.position.x.int32, projectile.position.y.int32, 3.0, YELLOW)

    block DRAW_GRENADES:
        if strategicMode: break DRAW_GRENADES
        let greyColor = Color(r: 100, g: 100, b: 100, a: 255)
        let greyDark = Color(r: 60, g: 60, b: 60, a: 255)
        let redBlink = Color(r: 220, g: 40, b: 40, a: 255)
        for grenade in game.grenades:
            if not grenade.alive: continue
            if not grenade.landed:
                let p = grenade.flightProgress
                let arc = sin(p * PI) * 20.0
                let shadowY = grenade.position.y
                drawCircle(grenade.position.x.int32, shadowY.int32, 3.0,
                    Color(r: 0, g: 0, b: 0, a: 100))
                drawCircle(grenade.position.x.int32, (grenade.position.y - arc).int32, 4.0, greyColor)
            else:
                let blink = grenade.fuseTimer < 0.5 and (int(grenade.fuseTimer * 10) mod 2 == 0)
                let c = if blink: redBlink else: greyDark
                drawCircle(grenade.position.x.int32, grenade.position.y.int32, 4.0, c)

    block DRAW_EXPLOSIONS:
        for explosion in game.explosions:
            let progress = 1.0 - explosion.timer / explosion.maxTimer
            let alpha = (255.0 * (explosion.timer / explosion.maxTimer)).uint8
            drawCircle(explosion.position.x.int32, explosion.position.y.int32, explosion.currentRadius.float32,
                Color(r: 255, g: (150.0 * (1.0 - progress)).uint8, b: 0, a: alpha))

    block DRAW_EFFECTS:
        if strategicMode: break DRAW_EFFECTS
        for effect in game.effects:
            let alpha = (180.0 * (effect.timer / effect.maxTimer)).uint8
            drawCircle(effect.position.x.int32, effect.position.y.int32, effect.radius.float32,
                Color(r: 255, g: 140, b: 0, a: alpha))

    block DRAW_SMOKE:
        if strategicMode: break DRAW_SMOKE
        for smoke in game.smokeParticles:
            let alpha = (140.0 * (smoke.timer / smoke.maxTimer)).uint8
            drawCircle(smoke.position.x.int32, smoke.position.y.int32, smoke.radius.float32,
                Color(r: 130, g: 130, b: 130, a: alpha))

        endMode2D()

    block DRAW_SELECTION_RECT:
        if game.isDragging and isMouseButtonDown(MouseButton.Left):
            let mouseScreen = getMousePosition()
            let x = min(game.dragStart.x, mouseScreen.x)
            let y = min(game.dragStart.y, mouseScreen.y)
            let width = abs(mouseScreen.x - game.dragStart.x)
            let height = abs(mouseScreen.y - game.dragStart.y)
            drawRectangle(x.int32, y.int32, width.int32, height.int32, Color(r: 255, g: 255, b: 0, a: 40))
            drawRectangleLines(x.int32, y.int32, width.int32, height.int32, YELLOW)

    block DEBUG_INFO:
        let zoomLevel =
            if zoom >= 2.0: "VERY_CLOSE"
            elif zoom >= 1.0: "CLOSE"
            elif zoom >= 0.5: "DEFAULT"
            elif zoom >= 0.25: "FAR"
            else: "VERY_FAR"
        drawText("FPS: " & $getFPS(), 10, 10, 20, GREEN)
        drawText("Zoom: " & zoomLevel, 10, 35, 20, GREEN)
