import std/random

import raylib

import ../shared/types
import ../shared/mapio
import ../shared/camera
import state
import ui
import draw

block BLOCK_SO_WE_DONT_SEGFAULT_DUE_TO_NIM_GARBAGE_COLLECTOR:

    block INIT:
        randomize()
        setConfigFlags(flags(FullscreenMode))
        initWindow(getScreenWidth(), getScreenHeight(), "Map Editor")
        setTargetFPS(60)

    var es = EditorState()
    es.mode = EditorMode.MainMenu
    es.activeTool = ToolGrass
    es.activeFaction = 0
    es.bonusOnCaptureValue = 100
    es.kraftPerSecondValue = 5
    es.newMapSizeField = TextField(value: "20")
    es.newMapChunkSizeField = TextField(value: "10")
    es.bonusOnCaptureField = TextField(value: "100")
    es.kraftPerSecondField = TextField(value: "5")

    proc resetCamera(es: var EditorState) =
        es.camera = Camera2D()
        es.camera.target = Vector2(x: es.map.mapSizePixels.float / 2.0, y: es.map.mapSizePixels.float / 2.0)
        es.camera.offset = Vector2(x: getScreenWidth().float / 2, y: getScreenHeight().float / 2)
        es.camera.rotation = 0
        es.camera.zoom = 0.5

    block GAME_LOOP:
        while not windowShouldClose() and not es.quitRequested:
            beginDrawing()
            clearBackground(BLACK)
            es.uiHovered = false

            case es.mode
            of EditorMode.MainMenu:
                let r = drawMainMenu(es)
                if r.newMap:
                    es.mode = EditorMode.NewMapDialog
                    es.statusMessage = ""
                elif r.loadMap:
                    es.availableMaps = listMaps()
                    es.mode = EditorMode.LoadMapDialog
                    es.statusMessage = ""
                elif r.quit:
                    es.quitRequested = true

            of EditorMode.NewMapDialog:
                let r = drawNewMapDialog(es)
                if r.back:
                    es.mode = EditorMode.MainMenu
                elif r.create:
                    let size = parseIntOr(es.newMapSizeField.value, 0)
                    let cst = parseIntOr(es.newMapChunkSizeField.value, 0)
                    if size >= 2 and size <= 200 and cst >= 2 and cst <= 50:
                        es.map = newEmptyMap(size, cst, generateTiles = false)
                        es.currentMapName = ""
                        resetCamera(es)
                        es.mode = EditorMode.Editing
                    else:
                        es.statusMessage = "Ungueltige Groesse"
                        es.mode = EditorMode.MainMenu

            of EditorMode.LoadMapDialog:
                let r = drawLoadMapDialog(es)
                if r.back:
                    es.mode = EditorMode.MainMenu
                elif r.selected.len > 0:
                    try:
                        es.map = loadMap(r.selected, generateTiles = false)
                        es.currentMapName = r.selected
                        resetCamera(es)
                        es.mode = EditorMode.Editing
                    except CatchableError as e:
                        es.statusMessage = "Fehler beim Laden: " & e.msg
                        es.mode = EditorMode.MainMenu

            of EditorMode.Editing:
                # Kamera
                updateCameraControls(es.camera, es.uiHovered)
                # Map zeichnen
                drawMapArea(es)
                # Toolbar zeichnen (setzt uiHovered)
                discard drawToolbar(es)
                # InfoBar
                drawInfoBar(es)
                # Edit-Klick auf Map
                block EDIT_CLICK:
                    if es.uiHovered: break EDIT_CLICK
                    let toolbarTop = getScreenHeight() - draw.TOOLBAR_HEIGHT
                    let mouseY = getMousePosition().y
                    if mouseY < 30 or mouseY >= toolbarTop.float: break EDIT_CLICK
                    let leftDown = isMouseButtonDown(MouseButton.Left) or isMouseButtonPressed(MouseButton.Left)
                    let rightDown = isMouseButtonDown(MouseButton.Right) or isMouseButtonPressed(MouseButton.Right)
                    if not (leftDown or rightDown): break EDIT_CLICK
                    let world = getScreenToWorld2D(getMousePosition(), es.camera)
                    let cs = es.map.chunkSizePixels
                    if world.x < 0 or world.y < 0: break EDIT_CLICK
                    let cx = int(world.x / cs.float)
                    let cy = int(world.y / cs.float)
                    if cx < 0 or cx >= es.map.mapSizeInChunks or cy < 0 or cy >= es.map.mapSizeInChunks:
                        break EDIT_CLICK
                    let idx = cx * es.map.mapSizeInChunks + cy
                    var chunk = es.map.chunks[idx]

                    # Rechtsklick bei Spawn-Tool: Spawn-Chunk zuruecksetzen
                    if rightDown and es.activeTool == ToolSpawn:
                        if chunk.kind == ChunkKind.Spawn:
                            applyChunkKind(chunk, ChunkKind.Grass)
                    # Buildings-Tool: links platzieren (nur auf Gras, max 1 pro Chunk), rechts entfernen
                    elif es.activeTool == ToolBuildings:
                        var existingIdx = -1
                        for i in 0 ..< es.map.buildings.len:
                            if es.map.buildings[i].chunkX == cx and es.map.buildings[i].chunkY == cy:
                                existingIdx = i
                                break
                        if rightDown and existingIdx >= 0:
                            es.map.buildings.delete(existingIdx)
                        elif leftDown and existingIdx < 0 and chunk.kind == ChunkKind.Grass:
                            es.map.buildings.add(MapBuilding(kind: es.activeBuilding, chunkX: cx, chunkY: cy))
                    # ToolErase (links): alles auf Default
                    elif leftDown and es.activeTool == ToolErase:
                        applyChunkKind(chunk, ChunkKind.Grass)
                        chunk.kraftBonusOnCapture = 0
                        chunk.kraftPerSecond = 0
                        chunk.kraftBonusClaimed = false
                    elif leftDown:
                        case es.activeTool
                        of ToolGrass:
                            applyChunkKind(chunk, ChunkKind.Grass)
                        of ToolMountain:
                            applyChunkKind(chunk, ChunkKind.Mountain)
                        of ToolWater:
                            applyChunkKind(chunk, ChunkKind.Water)
                        of ToolSpawn:
                            let n = es.map.mapSizeInChunks
                            let onEdge = cx == 0 or cy == 0 or cx == n - 1 or cy == n - 1
                            if onEdge:
                                applyChunkKind(chunk, ChunkKind.Spawn)
                                chunk.spawnForFaction = es.activeFaction
                        of ToolBonusOnCapture:
                            chunk.kraftBonusOnCapture = es.bonusOnCaptureValue
                        of ToolKraftPerSecond:
                            chunk.kraftPerSecond = es.kraftPerSecondValue
                        of ToolErase: discard  # oben behandelt
                        of ToolBuildings: discard  # oben behandelt
                    es.map.chunks[idx] = chunk

            of EditorMode.SaveDialog:
                drawMapArea(es)
                discard drawToolbar(es)
                drawInfoBar(es)
                let r = drawSaveDialog(es)
                if r.cancel:
                    es.mode = EditorMode.Editing
                elif r.save and es.saveNameField.value.len > 0:
                    try:
                        saveMap(es.map, es.saveNameField.value)
                        es.currentMapName = es.saveNameField.value
                        es.mode = EditorMode.Editing
                    except CatchableError as e:
                        es.statusMessage = "Fehler beim Speichern: " & e.msg

            endDrawing()

    closeWindow()
