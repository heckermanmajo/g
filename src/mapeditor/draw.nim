import raylib

import ../shared/types
import state
import ui

const TOOLBAR_HEIGHT* = 70

proc chunkColor(kind: ChunkKind): Color =
    case kind
    of ChunkKind.Grass: Color(r: 60, g: 120, b: 50, a: 255)
    of ChunkKind.Mountain: Color(r: 100, g: 80, b: 60, a: 255)
    of ChunkKind.Water: Color(r: 40, g: 80, b: 160, a: 255)
    of ChunkKind.Spawn: Color(r: 180, g: 180, b: 80, a: 255)

proc factionColor(idx: int): Color =
    case idx
    of 0: RED
    of 1: BLUE
    of 2: GREEN
    of 3: YELLOW
    of 4: PURPLE
    of 5: ORANGE
    of 6: Color(r: 255, g: 100, b: 200, a: 255)
    of 7: Color(r: 100, g: 255, b: 200, a: 255)
    else: GRAY

proc drawMapArea*(es: var EditorState) =
    beginMode2D(es.camera)
    let chunkSizePixels = es.map.chunkSizePixels
    let cps = es.map.mapSizeInChunks
    let highlightEdges = es.activeTool == ToolSpawn
    for i in 0 ..< es.map.chunks.len:
        let c = es.map.chunks[i]
        let cx = i div cps
        let cy = i mod cps
        let rect = Rectangle(
            x: cx.float * chunkSizePixels.float,
            y: cy.float * chunkSizePixels.float,
            width: chunkSizePixels.float,
            height: chunkSizePixels.float
        )
        drawRectangle(rect, chunkColor(c.kind))
        if highlightEdges:
            let onEdge = cx == 0 or cy == 0 or cx == cps - 1 or cy == cps - 1
            if onEdge:
                drawRectangle(rect, Color(r: 255, g: 255, b: 100, a: 60))
        # Spawn-Marker: Fraktionsfarbe als innerer Kreis
        if c.kind == ChunkKind.Spawn and c.spawnForFaction >= 0:
            let cxPx = rect.x + rect.width / 2.0
            let cyPx = rect.y + rect.height / 2.0
            drawCircle(Vector2(x: cxPx, y: cyPx), rect.width * 0.25, factionColor(c.spawnForFaction))
        # Bonus-Marker
        if c.kraftBonusOnCapture > 0:
            drawText("+" & $c.kraftBonusOnCapture, rect.x.int32 + 4, rect.y.int32 + 4, 16, WHITE)
        if c.kraftPerSecond > 0:
            drawText($c.kraftPerSecond & "/s", rect.x.int32 + 4, (rect.y + rect.height - 20.0).int32, 16, WHITE)
        # Gitter
        drawRectangleLines(rect, 1.0, Color(r: 0, g: 0, b: 0, a: 80))
    # Buildings zeichnen (auf Chunk-Mitte)
    for b in es.map.buildings:
        let bx = b.chunkX.float * chunkSizePixels.float + chunkSizePixels.float / 2.0
        let by = b.chunkY.float * chunkSizePixels.float + chunkSizePixels.float / 2.0
        let half = chunkSizePixels.float * 0.3
        drawRectangle(Rectangle(x: bx - half, y: by - half, width: half * 2, height: half * 2),
                      Color(r: 60, g: 60, b: 70, a: 255))
        drawRectangleLines(Rectangle(x: bx - half, y: by - half, width: half * 2, height: half * 2),
                           2.0, Color(r: 200, g: 200, b: 200, a: 255))
        drawText($b.kind, (bx - half + 4).int32, (by - half + 4).int32, 14, WHITE)
    endMode2D()

proc drawToolbar*(es: var EditorState): tuple[clicked: bool] =
    let screenW = getScreenWidth()
    let screenH = getScreenHeight()
    let toolbarY = screenH - TOOLBAR_HEIGHT
    var clicked = false

    drawRectangle(Rectangle(x: 0, y: toolbarY.float, width: screenW.float, height: TOOLBAR_HEIGHT.float),
                  Color(r: 20, g: 20, b: 20, a: 230))

    let toolbarRect = Rectangle(x: 0, y: toolbarY.float, width: screenW.float, height: TOOLBAR_HEIGHT.float)
    if mouseInRect(toolbarRect): es.uiHovered = true

    var x = BUTTON_PADDING
    let y = toolbarY + (TOOLBAR_HEIGHT - BUTTON_HEIGHT) div 2
    let bw = 110

    template toolBtn(label: string, tool: EditorTool) =
        let rect = Rectangle(x: x.float, y: y.float, width: bw.float, height: BUTTON_HEIGHT.float)
        if drawButton(rect, label, es.activeTool == tool):
            es.activeTool = tool
            clicked = true
        x += bw + BUTTON_PADDING

    toolBtn("Gras", ToolGrass)
    toolBtn("Berg", ToolMountain)
    toolBtn("Wasser", ToolWater)
    toolBtn("Spawn", ToolSpawn)
    toolBtn("Bonus+", ToolBonusOnCapture)
    toolBtn("Kraft/s", ToolKraftPerSecond)
    toolBtn("Buildings", ToolBuildings)
    toolBtn("Loeschen", ToolErase)

    # Kontext-Controls je nach Tool
    if es.activeTool == ToolSpawn:
        let rect = Rectangle(x: x.float, y: y.float, width: 180, height: BUTTON_HEIGHT.float)
        if drawButton(rect, "Fraktion: " & $es.activeFaction):
            es.activeFaction = (es.activeFaction + 1) mod 4
            clicked = true
        x += 180 + BUTTON_PADDING
    elif es.activeTool == ToolBonusOnCapture:
        let labelRect = Rectangle(x: x.float, y: y.float, width: 90, height: BUTTON_HEIGHT.float)
        drawText("Wert:", labelRect.x.int32, labelRect.y.int32 + 10, 20, WHITE)
        x += 60
        let fieldRect = Rectangle(x: x.float, y: y.float, width: 100, height: BUTTON_HEIGHT.float)
        drawTextField(fieldRect, es.bonusOnCaptureField, numericOnly = true)
        es.bonusOnCaptureValue = parseIntOr(es.bonusOnCaptureField.value, 0)
        x += 100 + BUTTON_PADDING
    elif es.activeTool == ToolKraftPerSecond:
        drawText("Wert:", x.int32, y.int32 + 10, 20, WHITE)
        x += 60
        let fieldRect = Rectangle(x: x.float, y: y.float, width: 100, height: BUTTON_HEIGHT.float)
        drawTextField(fieldRect, es.kraftPerSecondField, numericOnly = true)
        es.kraftPerSecondValue = parseIntOr(es.kraftPerSecondField.value, 0)
        x += 100 + BUTTON_PADDING

    # Sub-Toolbar fuer Buildings (zweite Reihe oberhalb)
    if es.activeTool == ToolBuildings:
        let subY = toolbarY - BUTTON_HEIGHT - BUTTON_PADDING
        let subBgRect = Rectangle(x: 0, y: (subY - BUTTON_PADDING).float,
                                  width: screenW.float,
                                  height: (BUTTON_HEIGHT + 2 * BUTTON_PADDING).float)
        drawRectangle(subBgRect, Color(r: 30, g: 30, b: 30, a: 230))
        if mouseInRect(subBgRect): es.uiHovered = true
        var sx = BUTTON_PADDING
        let bkRect = Rectangle(x: sx.float, y: subY.float, width: bw.float, height: BUTTON_HEIGHT.float)
        if drawButton(bkRect, "Bunker", es.activeBuilding == BuildingKind.Bunker):
            es.activeBuilding = BuildingKind.Bunker
            clicked = true
        sx += bw + BUTTON_PADDING

    # rechts: Speichern / Menu
    let rightEdge = screenW - BUTTON_PADDING
    let menuRect = Rectangle(x: (rightEdge - 120).float, y: y.float, width: 120, height: BUTTON_HEIGHT.float)
    if drawButton(menuRect, "Menu"):
        es.mode = EditorMode.MainMenu
        clicked = true
    let saveRect = Rectangle(x: (rightEdge - 120 - BUTTON_PADDING - 140).float, y: y.float, width: 140, height: BUTTON_HEIGHT.float)
    if drawButton(saveRect, "Speichern"):
        es.saveNameField.value = es.currentMapName
        es.saveNameField.active = true
        es.mode = EditorMode.SaveDialog
        clicked = true

    (clicked: clicked)

proc drawMainMenu*(es: var EditorState): tuple[newMap: bool, loadMap: bool, quit: bool] =
    let screenW = getScreenWidth()
    let screenH = getScreenHeight()
    drawRectangle(Rectangle(x: 0, y: 0, width: screenW.float, height: screenH.float),
                  Color(r: 30, g: 30, b: 40, a: 255))
    let title = "Map Editor"
    let titleSize: int32 = 60
    let tw = measureText(title, titleSize)
    drawText(title, (screenW.int32 - tw) div 2, 120, titleSize, WHITE)

    let bw = 300
    let bh = 60
    let cx = (screenW - bw) div 2
    var cy = 260
    let gap = 20

    let r1 = Rectangle(x: cx.float, y: cy.float, width: bw.float, height: bh.float)
    let newClicked = drawButton(r1, "Neue Map")
    cy += bh + gap
    let r2 = Rectangle(x: cx.float, y: cy.float, width: bw.float, height: bh.float)
    let loadClicked = drawButton(r2, "Map laden")
    cy += bh + gap
    let r3 = Rectangle(x: cx.float, y: cy.float, width: bw.float, height: bh.float)
    let quitClicked = drawButton(r3, "Beenden")

    if es.statusMessage.len > 0:
        let sw = measureText(es.statusMessage, 20)
        drawText(es.statusMessage, (screenW.int32 - sw) div 2, screenH.int32 - 60, 20, YELLOW)

    (newMap: newClicked, loadMap: loadClicked, quit: quitClicked)

proc drawNewMapDialog*(es: var EditorState): tuple[create: bool, back: bool] =
    let screenW = getScreenWidth()
    let screenH = getScreenHeight()
    drawRectangle(Rectangle(x: 0, y: 0, width: screenW.float, height: screenH.float),
                  Color(r: 30, g: 30, b: 40, a: 255))
    let title = "Neue Map"
    let ts: int32 = 40
    let tw = measureText(title, ts)
    drawText(title, (screenW.int32 - tw) div 2, 100, ts, WHITE)

    let bw = 300
    let cx = (screenW - bw) div 2
    var cy = 200

    drawText("Groesse in Chunks:", cx.int32, cy.int32, 20, WHITE)
    cy += 28
    let f1 = Rectangle(x: cx.float, y: cy.float, width: bw.float, height: 40)
    drawTextField(f1, es.newMapSizeField, numericOnly = true)
    cy += 60

    drawText("Chunk-Groesse in Tiles:", cx.int32, cy.int32, 20, WHITE)
    cy += 28
    let f2 = Rectangle(x: cx.float, y: cy.float, width: bw.float, height: 40)
    drawTextField(f2, es.newMapChunkSizeField, numericOnly = true)
    cy += 80

    let halfBw = (bw - 20) div 2
    let backRect = Rectangle(x: cx.float, y: cy.float, width: halfBw.float, height: 50)
    let backClicked = drawButton(backRect, "Zurueck")
    let createRect = Rectangle(x: (cx + halfBw + 20).float, y: cy.float, width: halfBw.float, height: 50)
    let createClicked = drawButton(createRect, "Erstellen")

    (create: createClicked, back: backClicked)

proc drawLoadMapDialog*(es: var EditorState): tuple[selected: string, back: bool] =
    let screenW = getScreenWidth()
    let screenH = getScreenHeight()
    drawRectangle(Rectangle(x: 0, y: 0, width: screenW.float, height: screenH.float),
                  Color(r: 30, g: 30, b: 40, a: 255))
    let title = "Map laden"
    let ts: int32 = 40
    let tw = measureText(title, ts)
    drawText(title, (screenW.int32 - tw) div 2, 80, ts, WHITE)

    var selected = ""
    let bw = 400
    let cx = (screenW - bw) div 2
    var cy = 170
    for name in es.availableMaps:
        let rect = Rectangle(x: cx.float, y: cy.float, width: bw.float, height: 40)
        if drawButton(rect, name):
            selected = name
        cy += 50
        if cy > screenH - 120: break

    if es.availableMaps.len == 0:
        let msg = "Keine Maps gefunden in maps/"
        let mw = measureText(msg, 20)
        drawText(msg, (screenW.int32 - mw) div 2, 200, 20, GRAY)

    let backRect = Rectangle(x: cx.float, y: (screenH - 70).float, width: bw.float, height: 50)
    let backClicked = drawButton(backRect, "Zurueck")

    (selected: selected, back: backClicked)

proc drawSaveDialog*(es: var EditorState): tuple[save: bool, cancel: bool] =
    let screenW = getScreenWidth()
    let screenH = getScreenHeight()
    # Editor-Hintergrund bleibt, wir zeichnen overlay
    drawRectangle(Rectangle(x: 0, y: 0, width: screenW.float, height: screenH.float),
                  Color(r: 0, g: 0, b: 0, a: 180))
    let bw = 400
    let bh = 240
    let cx = (screenW - bw) div 2
    let cy = (screenH - bh) div 2
    drawRectangle(Rectangle(x: cx.float, y: cy.float, width: bw.float, height: bh.float),
                  Color(r: 30, g: 30, b: 40, a: 255))
    drawRectangleLines(Rectangle(x: cx.float, y: cy.float, width: bw.float, height: bh.float), 1.0, WHITE)

    drawText("Map-Name:", (cx + 20).int32, (cy + 20).int32, 20, WHITE)
    let fieldRect = Rectangle(x: (cx + 20).float, y: (cy + 50).float, width: (bw - 40).float, height: 40)
    drawTextField(fieldRect, es.saveNameField)

    let halfBw = (bw - 60) div 2
    let y2 = cy + bh - 70
    let cancelRect = Rectangle(x: (cx + 20).float, y: y2.float, width: halfBw.float, height: 50)
    let cancelClicked = drawButton(cancelRect, "Abbrechen")
    let saveRect = Rectangle(x: (cx + 40 + halfBw).float, y: y2.float, width: halfBw.float, height: 50)
    let saveClicked = drawButton(saveRect, "Speichern")

    (save: saveClicked, cancel: cancelClicked)

proc drawInfoBar*(es: EditorState) =
    let info = "Map: " & (if es.currentMapName.len > 0: es.currentMapName else: "(unbenannt)") &
               "   Groesse: " & $es.map.mapSizeInChunks & "x" & $es.map.mapSizeInChunks
    drawRectangle(Rectangle(x: 0, y: 0, width: getScreenWidth().float, height: 30),
                  Color(r: 20, g: 20, b: 20, a: 200))
    drawText(info, 10, 6, 18, WHITE)
