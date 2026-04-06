import std/options
import std/random

import raylib

import share/share_types
import share/share_consts
import textures

type 

    MapSystem* = ref object
        ## Contains the map state.
        ## Also manages pathfinding
        ## Also has map related UI state, like f. e. the currently selected tile
        map: Map

        # Map related UI state
        userSelectedTile: Option[Tile]
        camera*: Camera2D

    Map* = ref object
        ## The map is made of a square map of chunks, and each chunk is made of a square of tiles.
        mapSizeInChunks: int
        chunkSizeInTiles: int
        chunks: seq[Chunk]
        allTiles: seq[Tile] # for easier access to all tiles, for example for pathfinding


    Chunk* = ref object
        ## A chunk is a square of tiles. It also contains the units that are currently on it, to make it easier to find them.
        ## Chunks serve game play purposes(map control) AND performance purposes(reduce needed calculations AND ai behavior).
        id: ChunkId
        units: seq[UnitId]
        tiles: seq[Tile]
        x: int
        y: int

        # gameplay relevant fields
        currentOwner: Option[FactionId]


    Tile* = ref object
        ## Single square of the map.
        id: TileId
        x: int
        y: int
        passable: bool
        kind*: TileKind
        textureIndex*: int


proc getId*(tile: Tile): TileId = tile.id
proc getId*(chunk: Chunk): ChunkId = chunk.id
proc beginMode2D*(mapSystem: MapSystem) = beginMode2D(mapSystem.camera)

proc getMapWidthPx*(mapSystem: MapSystem): int =
    mapSystem.map.mapSizeInChunks * mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE

proc getMapHeightPx*(mapSystem: MapSystem): int =
    mapSystem.map.mapSizeInChunks * mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE


proc initMapSystem*(
    chunksPerSide: int,
    chunkSizeInTiles: int
): MapSystem =
    ## Creates a new empty Map-System
    ## The map system is made of a square map of chunks, and each chunk is made of a square of tiles.
    var mapSystem = MapSystem()
    mapSystem.map = Map()
    mapSystem.map.mapSizeInChunks = chunksPerSide
    mapSystem.map.chunkSizeInTiles = chunkSizeInTiles
    mapSystem.map.chunks = @[]
    for chunkX in 0 ..< chunksPerSide:
        for chunkY in 0 ..< chunksPerSide:
            var chunk = Chunk()
            let chunkIndex = chunkX * chunksPerSide + chunkY
            chunk.id = ChunkId(chunkIndex) # since chunks do not change over time
            chunk.x = chunkX * chunkSizeInTiles * PIXELS_PER_TILE
            chunk.y = chunkY * chunkSizeInTiles * PIXELS_PER_TILE
            chunk.tiles = @[]
            for tileX in 0 ..< chunkSizeInTiles:
                for tileY in 0 ..< chunkSizeInTiles:
                    var tile = Tile()
                    let tileIndex = block:
                        let tilesInChunksBeforeThisTile = chunkIndex * chunkSizeInTiles * chunkSizeInTiles
                        let indexInThisChunk = tileX * chunkSizeInTiles + tileY
                        let totalIndex = tilesInChunksBeforeThisTile + indexInThisChunk
                        totalIndex
                    tile.id = TileId(tileIndex) # since tiles do not change over time
                    tile.x = chunk.x + tileX * PIXELS_PER_TILE
                    tile.y = chunk.y + tileY * PIXELS_PER_TILE
                    tile.kind = TileKind.Grass
                    tile.textureIndex = rand(5)
                    chunk.tiles.add(tile)
                    mapSystem.map.allTiles.add(tile)
            mapSystem.map.chunks.add(chunk)

    block INIT_CAMERA:
        mapSystem.camera = Camera2D()
        mapSystem.camera.target = Vector2(x:0, y:0)
        mapSystem.camera.offset = Vector2(x:getScreenWidth().float / 2, y:getScreenHeight().float / 2)
        mapSystem.camera.rotation = 0
        mapSystem.camera.zoom = 1

    return mapSystem


proc getTileById*(mapSystem: MapSystem, id: TileId): Option[Tile] = 
    ## Returns the tile with the given id, if it exists.
    ## Otherwise returns none(Tile).
    if id < 0 or id >= TileId(int.high): return none(Tile)
    return some(mapSystem.map.allTiles[int(id)])


proc getChunkById*(mapSystem: MapSystem, id: ChunkId): Option[Chunk] = 
    ## Returns the chunk with the given id, if it exists.
    ## Otherwise returns none(Chunk).
    if id < 0 or id >= ChunkId(int.high): return none(Chunk)
    return some(mapSystem.map.chunks[int(id)])


proc getTileAtPosition*(mapSystem: MapSystem, x: int, y: int): Option[Tile] =
    ## Returns the tile at the given ABSOLUTE PIXEL POSITION, if it exists.
    ## Otherwise returns none(Tile).

    if x < 0 or y < 0: return none(Tile)

    let chunkSizeInPixels = mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE
    let mapSizeInPixels = mapSystem.map.mapSizeInChunks * chunkSizeInPixels

    if x >= mapSizeInPixels or y >= mapSizeInPixels: return none(Tile)

    let chunkX = x div chunkSizeInPixels
    let chunkY = y div chunkSizeInPixels

    # Must match initMapSystem chunk insertion order: chunkX outer, chunkY inner
    let chunkIndexInSeq = chunkX * mapSystem.map.mapSizeInChunks + chunkY
    let chunk = mapSystem.map.chunks[chunkIndexInSeq]

    let tileX = (x mod chunkSizeInPixels) div PIXELS_PER_TILE
    let tileY = (y mod chunkSizeInPixels) div PIXELS_PER_TILE

    # Must match tile insertion order: tileX outer, tileY inner
    let tileIndexInSeq = tileX * mapSystem.map.chunkSizeInTiles + tileY

    return some(chunk.tiles[tileIndexInSeq])


proc getTileAtPosition*(mapSystem: MapSystem, x: float, y: float): Option[Tile] =
    ## Returns the tile at the given ABSOLUTE PIXEL POSITION, if it exists.
    ## Otherwise returns none(Tile).
        ## @see proc getTileAtPosition*(mapSystem: MapSystem, x: int, y: int)
    return getTileAtPosition(mapSystem, int(x), int(y))


proc getTileAtPosition*(mapSystem: MapSystem, v: Vector2): Option[Tile] =
    ## Returns the tile at the given ABSOLUTE PIXEL POSITION, if it exists.
    ## Otherwise returns none(Tile).
    ## @see proc getTileAtPosition*(mapSystem: MapSystem, x: int, y: int)
    return getTileAtPosition(mapSystem, int(v.x), int(v.y))


proc getChunkAtPosition*(mapSystem: MapSystem, x: int, y: int): Option[Chunk] =
    ## Returns the chunk at the given ABSOLUTE PIXEL POSITION, if it exists.
    ## Otherwise returns none(Chunk).
    if x < 0 or y < 0: return none(Chunk)
    let chunkSizeInPixels = mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE
    let mapSizeInPixels = mapSystem.map.mapSizeInChunks * chunkSizeInPixels
    if x >= mapSizeInPixels or y >= mapSizeInPixels: return none(Chunk)
    let chunkX = x div chunkSizeInPixels
    let chunkY = y div chunkSizeInPixels
    # Must match initMapSystem chunk insertion order: chunkX outer, chunkY inner
    let chunkIndexInSeq = chunkX * mapSystem.map.mapSizeInChunks + chunkY
    return some(mapSystem.map.chunks[chunkIndexInSeq])


proc getChunkAtPosition*(mapSystem: MapSystem, x: float, y: float): Option[Chunk] =
    ## Returns the chunk at the given ABSOLUTE PIXEL POSITION, if it exists.
    ## Otherwise returns none(Chunk).
    ## @see proc getChunkAtPosition*(mapSystem: MapSystem, x: int, y: int)
    return getChunkAtPosition(mapSystem, int(x), int(y))


proc getChunkAtPosition*(mapSystem: MapSystem, v: Vector2): Option[Chunk] =
    ## Returns the chunk at the given ABSOLUTE PIXEL POSITION, if it exists.
    ## Otherwise returns none(Chunk).
    ## @see proc getChunkAtPosition*(mapSystem: MapSystem, x: int, y: int)
    return getChunkAtPosition(mapSystem, int(v.x), int(v.y))


proc saveMapSystemToPath*(folderPath: string, mapSystem: MapSystem) =
    ## Saves the whole map system to the given folder path.
    ## Like this:
    ## folderPath/
    ##     mapSystem.ini 
    ##     chunks/
    ##         chunk1/
    ##             chunk.ini
    ##             tiles.csv
    discard


proc loadMapSystemFromPath*(folderPath: string): MapSystem =
    ## Loads the whole map system from the given folder path.
    ## checks fisrt that the folder structure is correct and all files
    ## are there.
    ## @see proc saveMapSystemToPath*(...)
    discard


proc updateUserMapInteraction*(
    mapSystem: MapSystem, 
    mouseClickAlreadyConsumed: bool
): bool =
    ## Updates the map system state based on the user interaction.
    ## For example, if the user clicks on a tile, it updates the userSelectedTile field.
    ## Also manages camera movement.
    
    ## TODO: we neeed to place the camera speed and the zoomspeed somewhere

    var mouseClickConsumed = mouseClickAlreadyConsumed

    block MOVE_CAMERA:
        let scrollSpeedZoomFactor = 1.0 / mapSystem.camera.zoom 

        let cameraSpeed = block:
            var speed = 10.0 * scrollSpeedZoomFactor
            if speed > 70.0: speed = 70.0 # cap the camera speed to prevent it from being too fast when zoomed out
            speed

        if isKeyDown(KeyboardKey.Right): mapSystem.camera.target.x += cameraSpeed
        if isKeyDown(KeyboardKey.Left): mapSystem.camera.target.x -= cameraSpeed
        if isKeyDown(KeyboardKey.Down): mapSystem.camera.target.y += cameraSpeed
        if isKeyDown(KeyboardKey.Up): mapSystem.camera.target.y -= cameraSpeed

        # wasd
        if isKeyDown(KeyboardKey.D): mapSystem.camera.target.x += cameraSpeed
        if isKeyDown(KeyboardKey.A): mapSystem.camera.target.x -= cameraSpeed
        if isKeyDown(KeyboardKey.S): mapSystem.camera.target.y += cameraSpeed
        if isKeyDown(KeyboardKey.W): mapSystem.camera.target.y -= cameraSpeed

        # also drag the camera with the middle mouse button pressed
        if isMouseButtonDown(MouseButton.Middle):
            let mouseDelta = getMouseDelta()
            mapSystem.camera.target.x -= mouseDelta.x * scrollSpeedZoomFactor
            mapSystem.camera.target.y -= mouseDelta.y * scrollSpeedZoomFactor

    block ZOOM_CAMERA:
        let zoomSpeed = 0.1
        if isKeyDown(KeyboardKey.Equal): mapSystem.camera.zoom += zoomSpeed
        if isKeyDown(KeyboardKey.Minus): mapSystem.camera.zoom -= zoomSpeed
        # also zoom the camera with the mouse wheel
        let mouseWheelMove = getMouseWheelMove()
        mapSystem.camera.zoom += mouseWheelMove * zoomSpeed
        # clamp the zoom level to prevent it from being too small or too big
        if mapSystem.camera.zoom < 0.1: mapSystem.camera.zoom = 0.1
        if mapSystem.camera.zoom > 5.0: mapSystem.camera.zoom = 5.0

    
    block SELECT_TILE:
        if mouseClickConsumed: break SELECT_TILE
        if isMouseButtonPressed(MouseButton.Left):
            let mousePosition = getMousePosition()
            let tileAtMouse = getTileAtPosition(mapSystem, mousePosition)
            if tileAtMouse.isSome:
                mapSystem.userSelectedTile = tileAtMouse
                mouseClickConsumed = true

    return mouseClickConsumed


proc getZoomLevelFromCameraZoom*(mapSystem: MapSystem): ZoomLevel =
    ## Returns the zoom level based on the camera zoom value.
    ## The zoom level is used to determine what details to draw on the map or for units.
    ## @see shared.shared_types.ZoomLevel
    let zoom = mapSystem.camera.zoom
    if zoom >= 2.0: return ZoomLevel.VERY_CLOSE
    elif zoom >= 1.0: return ZoomLevel.CLOSE
    elif zoom >= 0.5: return ZoomLevel.DEFAULT
    elif zoom >= 0.25: return ZoomLevel.FAR
    else: return ZoomLevel.VERY_FAR
        

proc drawMap*(mapSystem: MapSystem) =
    ## Draws the map on the screen, using raylib.
    ## For now, just draws the tiles as white squares, and the chunks as red squares.

    proc chunkInUserView(mapSystem: MapSystem, chunk: Chunk): bool =
        ## Returns true if the chunk is in the user's view, based on the camera position and zoom.
        ## Can be used to only draw units and tiles of chunks that are in the user's view, to improve performance.
        let chunkSizeInPixels = mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE
        let chunkRect = Rectangle(
            x: chunk.x.float,
            y: chunk.y.float,
            width: chunkSizeInPixels.float,
            height: chunkSizeInPixels.float
        )
        return checkCollisionRecs(
            chunkRect,
            Rectangle(
                x: mapSystem.camera.target.x - mapSystem.camera.offset.x / mapSystem.camera.zoom,
                y: mapSystem.camera.target.y - mapSystem.camera.offset.y / mapSystem.camera.zoom,
                width: getScreenWidth().float / mapSystem.camera.zoom,
                height: getScreenHeight().float / mapSystem.camera.zoom
            )
        )

    let zoomLevel = getZoomLevelFromCameraZoom(mapSystem)
    let dontDisplayTiles = (
        zoomLevel == ZoomLevel.VERY_FAR or 
        zoomLevel == ZoomLevel.FAR
    )

    for chunk in mapSystem.map.chunks:
        if not chunkInUserView(mapSystem, chunk): continue
        if not dontDisplayTiles:
            for tile in chunk.tiles:
                let i = tile.textureIndex
                let margin = 0.14
                let mx = grassTextures[i].width.float * margin
                let my = grassTextures[i].height.float * margin
                let source = Rectangle(
                    x: mx, y: my,
                    width: grassTextures[i].width.float - 2 * mx,
                    height: grassTextures[i].height.float - 2 * my
                )
                let dest = Rectangle(
                    x: tile.x.float,
                    y: tile.y.float,
                    width: PIXELS_PER_TILE.float,
                    height: PIXELS_PER_TILE.float
                )
                drawTexture(grassTextures[i], source, dest, Vector2(x: 0, y: 0), 0, WHITE)
        drawRectangleLines(
            chunk.x.int32,
            chunk.y.int32,
            (mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE).int32,
            (mapSystem.map.chunkSizeInTiles * PIXELS_PER_TILE).int32,
            GRAY
        )