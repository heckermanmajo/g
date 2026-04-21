import std/options
import std/math
import std/random

import raylib

import ../shared/types
import pathfinding

const PLAYER_FACTION = 0

proc handleInput*(game: var GameState) =
    let chunkSizePixels = game.map.chunkSizePixels
    let mapSizePixels = game.map.mapSizePixels

    block INPUT_CAMERA:
        block MOVE_CAMERA:
            let scrollSpeedZoomFactor = 1.0 / game.camera.zoom
            let cameraSpeed = min(10.0 * scrollSpeedZoomFactor, 70.0)

            if isKeyDown(KeyboardKey.Right) or isKeyDown(KeyboardKey.D): game.camera.target.x += cameraSpeed
            if isKeyDown(KeyboardKey.Left) or isKeyDown(KeyboardKey.A): game.camera.target.x -= cameraSpeed
            if isKeyDown(KeyboardKey.Down) or isKeyDown(KeyboardKey.S): game.camera.target.y += cameraSpeed
            if isKeyDown(KeyboardKey.Up) or isKeyDown(KeyboardKey.W): game.camera.target.y -= cameraSpeed

            if isMouseButtonDown(MouseButton.Middle):
                let mouseDelta = getMouseDelta()
                game.camera.target.x -= mouseDelta.x * scrollSpeedZoomFactor
                game.camera.target.y -= mouseDelta.y * scrollSpeedZoomFactor

        block ZOOM_CAMERA:
            let zoomSpeed = 0.1
            if isKeyDown(KeyboardKey.Equal): game.camera.zoom += zoomSpeed
            if isKeyDown(KeyboardKey.Minus): game.camera.zoom -= zoomSpeed
            game.camera.zoom += getMouseWheelMove() * zoomSpeed
            game.camera.zoom = clamp(game.camera.zoom, 0.1, 5.0)

    block INPUT_SELECTION:
        if game.uiHovered: break INPUT_SELECTION
        let mouseScreen = getMousePosition()
        let mouseWorld = getScreenToWorld2D(mouseScreen, game.camera)

        if isMouseButtonPressed(MouseButton.Left):
            game.isDragging = true
            game.dragStart = mouseScreen
            game.dragStartWorld = mouseWorld

        if isMouseButtonReleased(MouseButton.Left) and game.isDragging:
            game.isDragging = false
            let dragDeltaX = mouseScreen.x - game.dragStart.x
            let dragDeltaY = mouseScreen.y - game.dragStart.y

            if abs(dragDeltaX) < 5.0 and abs(dragDeltaY) < 5.0:
                block CLICK_SELECT:
                    var bestIdx = -1
                    var bestDist = float.high
                    for i in 0 ..< game.units.len:
                        let unit = game.units[i]
                        if not unit.alive or unit.inTransportOf >= 0 or unit.factionIndex != PLAYER_FACTION: continue
                        let distance = sqrt((unit.position.x - mouseWorld.x) * (unit.position.x - mouseWorld.x) +
                                     (unit.position.y - mouseWorld.y) * (unit.position.y - mouseWorld.y))
                        let hitRadius = if unit.definition.visualKind in {VisualKind.Circle, VisualKind.Sprite}: unit.definition.radius
                                        else: max(unit.definition.width, unit.definition.height) / 2.0
                        if distance < hitRadius and distance < bestDist:
                            bestDist = distance
                            bestIdx = i
                    if bestIdx >= 0:
                        game.selectedUnits = @[bestIdx]
                        game.selectedBuilding = -1
                    else:
                        game.selectedUnits = @[]
                        var bldIdx = -1
                        let halfSize = 30.0
                        for i in 0 ..< game.buildings.len:
                            let b = game.buildings[i]
                            if not b.alive: continue
                            if mouseWorld.x >= b.position.x - halfSize and mouseWorld.x < b.position.x + halfSize and
                               mouseWorld.y >= b.position.y - halfSize and mouseWorld.y < b.position.y + halfSize:
                                bldIdx = i
                                break
                        game.selectedBuilding = bldIdx
            else:
                block RECT_SELECT:
                    let endWorld = mouseWorld
                    let x1 = min(game.dragStartWorld.x, endWorld.x)
                    let y1 = min(game.dragStartWorld.y, endWorld.y)
                    let x2 = max(game.dragStartWorld.x, endWorld.x)
                    let y2 = max(game.dragStartWorld.y, endWorld.y)
                    let rect = Rectangle(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
                    var ownUnits: seq[int] = @[]
                    for i in 0 ..< game.units.len:
                        let unit = game.units[i]
                        if unit.alive and unit.inTransportOf < 0 and unit.factionIndex == PLAYER_FACTION and
                           unit.position.x >= rect.x and unit.position.x < rect.x + rect.width and
                           unit.position.y >= rect.y and unit.position.y < rect.y + rect.height:
                            ownUnits.add(i)
                    game.selectedUnits = ownUnits

    block INPUT_MOVE_COMMAND:
        if game.uiHovered: break INPUT_MOVE_COMMAND
        if game.selectedUnits.len > 0 and isMouseButtonPressed(MouseButton.Right):
            let mouseWorld = getScreenToWorld2D(getMousePosition(), game.camera)
            let chunkX = clamp(mouseWorld.x.int, 0, mapSizePixels - 1) div chunkSizePixels
            let chunkY = clamp(mouseWorld.y.int, 0, mapSizePixels - 1) div chunkSizePixels
            let targetChunkIdx = chunkX * game.map.mapSizeInChunks + chunkY
            let targetChunk = game.map.chunks[targetChunkIdx]
            let count = game.selectedUnits.len
            let margin = 20.0

            # Pruefen ob ein LKW auf ein Geschuetz rechtsklickt (Ankoppeln)
            var towTargetIdx = -1
            if count == 1:
                let unitIdx = game.selectedUnits[0]
                if game.units[unitIdx].definition.canTransport and game.units[unitIdx].towingEmplacement < 0:
                    let towRadius = 60.0
                    for i in 0 ..< game.units.len:
                        if not game.units[i].alive: continue
                        if not game.units[i].definition.isEmplacement: continue
                        if not game.units[i].definition.canBeTowed: continue
                        if game.units[i].towedByUnit >= 0: continue  # schon angekoppelt
                        let dx = game.units[i].position.x - mouseWorld.x
                        let dy = game.units[i].position.y - mouseWorld.y
                        let dist = sqrt(dx * dx + dy * dy)
                        if dist < towRadius:
                            towTargetIdx = i
                            break

            if towTargetIdx >= 0:
                # LKW faehrt zum Geschuetz — towTarget merken, Ankopplung in update
                let unitIdx = game.selectedUnits[0]
                game.units[unitIdx].towTarget = towTargetIdx
                let emplacementPos = game.units[towTargetIdx].position
                let path = game.findPath(game.units[unitIdx].currentChunk, game.units[towTargetIdx].currentChunk)
                game.units[unitIdx].path = path
                game.units[unitIdx].finalPosition = some(emplacementPos)
                if path.len > 1:
                    let chunk = game.map.chunks[path[0]]
                    let half = chunkSizePixels.float / 2.0
                    game.units[unitIdx].targetPosition = some(Vector2(x: chunk.x.float + half, y: chunk.y.float + half))
                else:
                    game.units[unitIdx].targetPosition = some(emplacementPos)
            else:
                for _, unitIdx in game.selectedUnits:
                    let finalPosition = if count == 1: mouseWorld
                        else: Vector2(
                            x: targetChunk.x.float + margin + rand(chunkSizePixels.float - 2 * margin),
                            y: targetChunk.y.float + margin + rand(chunkSizePixels.float - 2 * margin)
                        )
                    let path = game.findPath(game.units[unitIdx].currentChunk, targetChunkIdx)
                    game.units[unitIdx].path = path
                    game.units[unitIdx].finalPosition = some(finalPosition)
                    if path.len > 1:
                        let chunk = game.map.chunks[path[0]]
                        let half = chunkSizePixels.float / 2.0
                        game.units[unitIdx].targetPosition = some(Vector2(x: chunk.x.float + half, y: chunk.y.float + half))
                    else:
                        game.units[unitIdx].targetPosition = some(finalPosition)

    block INPUT_UNLOAD:
        if isKeyPressed(KeyboardKey.U):
            block UNLOAD_BUILDING:
                let b = game.selectedBuilding
                if b < 0: break UNLOAD_BUILDING
                if not game.buildings[b].alive: break UNLOAD_BUILDING
                let pos = game.buildings[b].position
                let chunkIdx = game.buildings[b].currentChunk
                let count = game.buildings[b].occupantIndices.len
                for pi in 0 ..< count:
                    let solIdx = game.buildings[b].occupantIndices[pi]
                    if not game.units[solIdx].alive: continue
                    let angle = (pi.float / max(count, 1).float) * 2.0 * PI
                    let offset = 45.0
                    game.units[solIdx].inBuilding = -1
                    game.units[solIdx].inTransportOf = -1
                    game.units[solIdx].position = Vector2(
                        x: pos.x + cos(angle) * offset,
                        y: pos.y + sin(angle) * offset
                    )
                    game.units[solIdx].currentChunk = chunkIdx
                    game.units[solIdx].targetPosition = none(Vector2)
                    game.units[solIdx].finalPosition = none(Vector2)
                    game.units[solIdx].path = @[]
                game.buildings[b].occupantIndices = @[]

            for unitIdx in game.selectedUnits:
                if not game.units[unitIdx].alive: continue

                # Geschuetz-Crew entladen (wenn Geschuetz selektiert)
                if game.units[unitIdx].definition.isEmplacement:
                    for crewIdx in game.units[unitIdx].crewIndices:
                        if not game.units[crewIdx].alive: continue
                        game.units[crewIdx].assignedEmplacement = -1
                        let angle = rand(0.0 .. 2.0 * PI)
                        let offset = 40.0
                        game.units[crewIdx].position.x = game.units[unitIdx].position.x + cos(angle) * offset
                        game.units[crewIdx].position.y = game.units[unitIdx].position.y + sin(angle) * offset
                    game.units[unitIdx].crewIndices = @[]
                    continue

                if not game.units[unitIdx].definition.canTransport: continue

                # Stufe 1: Geschuetz abkoppeln
                let towIdx = game.units[unitIdx].towingEmplacement
                if towIdx >= 0:
                    game.units[towIdx].towedByUnit = -1
                    game.units[unitIdx].towingEmplacement = -1
                    continue  # erstes U = nur Geschuetz abkoppeln

                # Stufe 2: Soldaten entladen
                if game.units[unitIdx].passengerIndices.len == 0: continue
                let pos = game.units[unitIdx].position
                let chunkIdx = game.units[unitIdx].currentChunk
                let count = game.units[unitIdx].passengerIndices.len
                for pi in 0 ..< count:
                    let solIdx = game.units[unitIdx].passengerIndices[pi]
                    if not game.units[solIdx].alive: continue
                    let angle = (pi.float / count.float) * 2.0 * PI
                    let offset = 40.0
                    game.units[solIdx].inTransportOf = -1
                    game.units[solIdx].position = Vector2(
                        x: pos.x + cos(angle) * offset,
                        y: pos.y + sin(angle) * offset
                    )
                    game.units[solIdx].currentChunk = chunkIdx
                    game.units[solIdx].targetPosition = none(Vector2)
                    game.units[solIdx].finalPosition = none(Vector2)
                    game.units[solIdx].path = @[]
                game.units[unitIdx].passengerIndices = @[]

    block INPUT_LOAD:
        if isKeyPressed(KeyboardKey.L):
            block LOAD_BUILDING:
                let b = game.selectedBuilding
                if b < 0: break LOAD_BUILDING
                if not game.buildings[b].alive: break LOAD_BUILDING
                if game.buildings[b].kind != BuildingKind.Bunker: break LOAD_BUILDING
                if game.buildings[b].factionIndex >= 0 and game.buildings[b].factionIndex != PLAYER_FACTION: break LOAD_BUILDING
                let maxO = game.buildings[b].maxOccupants
                if game.buildings[b].occupantIndices.len >= maxO: break LOAD_BUILDING
                let pos = game.buildings[b].position
                let loadRadius = 120.0
                for i in 0 ..< game.units.len:
                    if game.buildings[b].occupantIndices.len >= maxO: break
                    if not game.units[i].alive: continue
                    if game.units[i].factionIndex != PLAYER_FACTION: continue
                    if game.units[i].inTransportOf >= 0: continue
                    if game.units[i].inBuilding >= 0: continue
                    if game.units[i].assignedEmplacement >= 0: continue
                    if game.units[i].definition.canTransport: continue
                    if game.units[i].definition.isEmplacement: continue
                    if game.units[i].definition.damageCategory != DamageCategory.Light: continue
                    let dx = game.units[i].position.x - pos.x
                    let dy = game.units[i].position.y - pos.y
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist <= loadRadius:
                        if game.buildings[b].factionIndex < 0:
                            game.buildings[b].factionIndex = PLAYER_FACTION
                        game.units[i].inBuilding = b
                        game.units[i].inTransportOf = b
                        game.units[i].targetPosition = none(Vector2)
                        game.units[i].finalPosition = none(Vector2)
                        game.units[i].path = @[]
                        game.buildings[b].occupantIndices.add(i)

            for unitIdx in game.selectedUnits:
                if not game.units[unitIdx].alive: continue
                if not game.units[unitIdx].definition.canTransport: continue
                let maxP = game.units[unitIdx].definition.maxPassengers
                if game.units[unitIdx].passengerIndices.len >= maxP: continue
                let pos = game.units[unitIdx].position
                let faction = game.units[unitIdx].factionIndex
                let loadRadius = 80.0
                for i in 0 ..< game.units.len:
                    if game.units[unitIdx].passengerIndices.len >= maxP: break
                    if i == unitIdx: continue
                    if not game.units[i].alive: continue
                    if game.units[i].inTransportOf >= 0: continue
                    if game.units[i].factionIndex != faction: continue
                    if game.units[i].definition.canTransport: continue  # keine Transporter einladen
                    if game.units[i].definition.isEmplacement: continue  # keine Geschuetze einladen
                    if game.units[i].assignedEmplacement >= 0: continue  # Crew nicht einladen
                    let dx = game.units[i].position.x - pos.x
                    let dy = game.units[i].position.y - pos.y
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist <= loadRadius:
                        game.units[i].inTransportOf = unitIdx
                        game.units[unitIdx].passengerIndices.add(i)
