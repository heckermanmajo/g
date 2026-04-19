import std/tables
import std/math

import raylib

import types

const PLAYER_FACTION = 0
const ICON_SIZE = 64
const ICON_PAD = 8
const TOGGLE_BTN_W = 120
const TOGGLE_BTN_H = 40

proc pointInRect(px, py: float, r: Rectangle): bool =
    px >= r.x and px < r.x + r.width and py >= r.y and py < r.y + r.height

proc drawUI*(game: var GameState) =
    let screenW = getScreenWidth().float
    let screenH = getScreenHeight().float
    let mousePos = getMousePosition()
    let mouseClick = isMouseButtonPressed(MouseButton.Left)
    game.uiHovered = false

    # DEBUG: sichtbar machen dass drawUI laeuft
    drawText("UI ACTIVE - screenH: " & $screenH.int, 300, 10, 20, RED)

    block TOGGLE_SPAWN_BUTTON:
        let btnRect = Rectangle(
            x: ICON_PAD.float,
            y: screenH - TOGGLE_BTN_H.float - 80,
            width: TOGGLE_BTN_W.float,
            height: TOGGLE_BTN_H.float
        )
        let hovered = pointInRect(mousePos.x, mousePos.y, btnRect)
        if hovered: game.uiHovered = true

        let btnColor = if game.spawnMenuOpen: Color(r: 80, g: 160, b: 80, a: 240)
                        elif hovered: Color(r: 100, g: 100, b: 100, a: 240)
                        else: Color(r: 70, g: 70, b: 70, a: 230)
        drawRectangle(btnRect.x.int32, btnRect.y.int32, btnRect.width.int32, btnRect.height.int32, btnColor)
        drawRectangleLines(btnRect.x.int32, btnRect.y.int32, btnRect.width.int32, btnRect.height.int32, WHITE)
        let label = if game.spawnMenuOpen: "SPAWN [X]" else: "SPAWN"
        drawText(label, (btnRect.x + 10).int32, (btnRect.y + 10).int32, 20, WHITE)

        if hovered and mouseClick:
            game.spawnMenuOpen = not game.spawnMenuOpen

    block SPAWN_MENU:
        if not game.spawnMenuOpen: break SPAWN_MENU

        block KRAFT_DISPLAY:
            drawText("KRAFT: " & $game.factions[PLAYER_FACTION].kraft,
                (ICON_PAD + TOGGLE_BTN_W + ICON_PAD * 2).int32,
                (screenH - TOGGLE_BTN_H.float - ICON_PAD.float + 10).int32,
                20, YELLOW)

        block TROOP_ICONS:
            let totalTroops = game.troopDefs.len
            let troopIconW = 100
            let troopIconH = 80
            let menuW = totalTroops * (troopIconW + ICON_PAD) + ICON_PAD
            let menuX = (screenW - menuW.float) / 2.0
            let menuY = screenH - troopIconH.float - ICON_PAD.float * 2 - TOGGLE_BTN_H.float - ICON_PAD.float

            let bgRect = Rectangle(
                x: menuX - ICON_PAD.float,
                y: menuY - ICON_PAD.float,
                width: menuW.float + ICON_PAD.float,
                height: troopIconH.float + ICON_PAD.float * 2
            )
            drawRectangle(bgRect.x.int32, bgRect.y.int32, bgRect.width.int32, bgRect.height.int32,
                Color(r: 30, g: 30, b: 30, a: 200))
            drawRectangleLines(bgRect.x.int32, bgRect.y.int32, bgRect.width.int32, bgRect.height.int32,
                Color(r: 150, g: 150, b: 150, a: 200))

            if pointInRect(mousePos.x, mousePos.y, bgRect): game.uiHovered = true

            for i in 0 ..< totalTroops:
                let iconX = menuX + (i * (troopIconW + ICON_PAD)).float
                let iconY = menuY
                let iconRect = Rectangle(x: iconX, y: iconY, width: troopIconW.float, height: troopIconH.float)
                let hovered = pointInRect(mousePos.x, mousePos.y, iconRect)
                let canAfford = game.factions[PLAYER_FACTION].kraft >= game.troopDefs[i].kraftCost

                # icon hintergrund
                let bgColor = if not canAfford: Color(r: 60, g: 20, b: 20, a: 220)
                              elif hovered: Color(r: 100, g: 100, b: 100, a: 220)
                              else: Color(r: 60, g: 60, b: 60, a: 220)
                drawRectangle(iconX.int32, iconY.int32, troopIconW.int32, troopIconH.int32, bgColor)

                # trupp name
                drawText(game.troopDefs[i].name, (iconX + 4).int32, (iconY + 4).int32, 10, WHITE)

                # kraft-kosten
                let costStr = $game.troopDefs[i].kraftCost
                let costColor = if canAfford: YELLOW else: RED
                drawText(costStr, (iconX + 4).int32, (iconY + troopIconH.float - 16).int32, 14, costColor)

                # rahmen
                let borderColor = if hovered and canAfford: YELLOW else: GRAY
                drawRectangleLines(iconX.int32, iconY.int32, troopIconW.int32, troopIconH.int32, borderColor)

                # tooltip bei hover: zeige Units
                if hovered:
                    var tooltipY = menuY - 20.0
                    for entry in game.troopDefs[i].entries:
                        let entryStr = $entry.count & "x " & game.unitDefs[entry.unitDefIndex].name
                        tooltipY -= 14.0
                        drawText(entryStr, (iconX).int32, tooltipY.int32, 12, WHITE)

                # klick -> spawn trupp
                if hovered and mouseClick and canAfford:
                    var spawnChunk = -1
                    for ci in 0 ..< game.map.chunks.len:
                        if game.map.chunks[ci].spawnForFaction == PLAYER_FACTION:
                            spawnChunk = ci
                            break
                    if spawnChunk >= 0:
                        game.factions[PLAYER_FACTION].kraft -= game.troopDefs[i].kraftCost
                        game.factions[PLAYER_FACTION].troopSpawnQueue.add(TroopSpawnRequest(
                            troopDefIndex: i,
                            factionIndex: PLAYER_FACTION,
                            spawnChunkIndex: spawnChunk,
                            timer: SPAWN_TIME
                        ))

        block SPAWN_QUEUE_DISPLAY:
            let queue = game.factions[PLAYER_FACTION].troopSpawnQueue
            if queue.len == 0: break SPAWN_QUEUE_DISPLAY

            let queueX = ICON_PAD.float
            let queueY = ICON_PAD.float
            let queueIconW = 100
            let queueIconH = 48
            let queueW = queue.len * (queueIconW + ICON_PAD) + ICON_PAD

            let queueBg = Rectangle(
                x: queueX - ICON_PAD.float,
                y: queueY - ICON_PAD.float,
                width: queueW.float + ICON_PAD.float,
                height: queueIconH.float + ICON_PAD.float * 2 + 16
            )
            drawRectangle(queueBg.x.int32, queueBg.y.int32, queueBg.width.int32, queueBg.height.int32,
                Color(r: 30, g: 30, b: 30, a: 200))
            drawRectangleLines(queueBg.x.int32, queueBg.y.int32, queueBg.width.int32, queueBg.height.int32,
                Color(r: 150, g: 150, b: 150, a: 200))

            if pointInRect(mousePos.x, mousePos.y, queueBg): game.uiHovered = true

            for i in 0 ..< queue.len:
                let ix = queueX + (i * (queueIconW + ICON_PAD)).float
                let iy = queueY

                drawRectangle(ix.int32, iy.int32, queueIconW.int32, queueIconH.int32,
                    Color(r: 50, g: 50, b: 50, a: 220))

                let troopName = game.troopDefs[queue[i].troopDefIndex].name
                drawText(troopName, (ix + 4).int32, (iy + 4).int32, 10, WHITE)

                # timer-balken unten
                let progress = 1.0 - queue[i].timer / SPAWN_TIME
                let barY = iy + queueIconH.float + 2
                drawRectangle(ix.int32, barY.int32, queueIconW.int32, 10, DARKGRAY)
                drawRectangle(ix.int32, barY.int32, (queueIconW.float * progress).int32, 10, GREEN)

                # timer-text
                let timerStr = $queue[i].timer.int & "s"
                drawText(timerStr, (ix + 2).int32, (barY + 1).int32, 8, WHITE)

                drawRectangleLines(ix.int32, iy.int32, queueIconW.int32, queueIconH.int32, GRAY)

    block SELECTED_UNIT_INFO:
        if game.selectedUnits.len == 0: break SELECTED_UNIT_INFO
        let unitIdx = game.selectedUnits[0]
        if unitIdx >= game.units.len: break SELECTED_UNIT_INFO
        if not game.units[unitIdx].alive: break SELECTED_UNIT_INFO
        let unit = game.units[unitIdx]

        let panelW = 180.0
        let panelH = 120.0
        let panelX = screenW - panelW - ICON_PAD.float
        let panelY = screenH - panelH - ICON_PAD.float
        let panelRect = Rectangle(x: panelX, y: panelY, width: panelW, height: panelH)

        if pointInRect(mousePos.x, mousePos.y, panelRect): game.uiHovered = true

        drawRectangle(panelX.int32, panelY.int32, panelW.int32, panelH.int32,
            Color(r: 30, g: 30, b: 30, a: 200))
        drawRectangleLines(panelX.int32, panelY.int32, panelW.int32, panelH.int32,
            Color(r: 150, g: 150, b: 150, a: 200))

        # icon
        let iconX = panelX + ICON_PAD.float
        let iconY = panelY + ICON_PAD.float
        let iconSz = 64
        let texPath = if unit.factionIndex == 0: unit.definition.texturePathRed
                      else: unit.definition.texturePathBlue
        if texPath != "" and texPath in game.textures:
            let texPtr = addr game.textures[texPath]
            let texW = texPtr[].width.float
            let texH = texPtr[].height.float
            let scale = min((iconSz - 4).float / texW, (iconSz - 4).float / texH)
            let destW = texW * scale
            let destH = texH * scale
            let oX = iconX + (iconSz.float - destW) / 2.0
            let oY = iconY + (iconSz.float - destH) / 2.0
            let source = Rectangle(x: 0, y: 0, width: texW, height: texH)
            let dest = Rectangle(x: oX, y: oY, width: destW, height: destH)
            drawTexture(texPtr[], source, dest, Vector2(x: 0, y: 0), 0, WHITE)
        drawRectangleLines(iconX.int32, iconY.int32, iconSz.int32, iconSz.int32, GRAY)

        # name + hp rechts vom icon
        let textX = iconX + iconSz.float + ICON_PAD.float
        let textY = iconY
        drawText(unit.definition.name, textX.int32, textY.int32, 14, WHITE)

        let hpStr = $unit.health & "/" & $unit.definition.baseHealth
        drawText(hpStr, textX.int32, (textY + 18).int32, 14, GREEN)

        # granaten
        if unit.definition.grenadeDefIndex >= 0:
            let gDef = game.grenadeDefs[unit.definition.grenadeDefIndex]
            let gStr = gDef.name & " x" & $unit.grenadeAmmo
            let gColor = if unit.grenadeAmmo > 0: Color(r: 220, g: 200, b: 100, a: 255)
                         else: Color(r: 120, g: 120, b: 120, a: 255)
            drawText(gStr, textX.int32, (textY + 36).int32, 12, gColor)

        # selected count
        if game.selectedUnits.len > 1:
            let countStr = $game.selectedUnits.len & " units"
            drawText(countStr, textX.int32, (textY + 54).int32, 14, YELLOW)

    block UI_VICTORY_SCREEN:
        if not game.gameOver: break UI_VICTORY_SCREEN
        drawRectangle(0.int32, 0.int32, screenW.int32, screenH.int32, Color(r: 0, g: 0, b: 0, a: 180))
        let label = if game.winnerFactionIndex == PLAYER_FACTION: "SIEG" else: "NIEDERLAGE"
        let fontSize: int32 = 80
        let textW = measureText(label, fontSize)
        let tx = ((screenW - textW.float) / 2.0).int32
        let ty = ((screenH - fontSize.float) / 2.0).int32
        drawText(label, tx, ty, fontSize, WHITE)
