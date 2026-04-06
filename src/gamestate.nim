
import raylib

import map
import faction

type 

    GameState* = ref object
        ## GameState means one game state, that can be loaded, saved, etc.
        #effectSystem: EffectSystem
        mapSystem: MapSystem
        diplomacySystem: DiplomacySystem

proc newGameState*(): GameState =
    var gameState = GameState()
    #gameState.effectSystem = initEffectSystem()
    gameState.mapSystem = initMapSystem(
        chunksPerSide = 10,
        chunkSizeInTiles = 10
    )
    gameState.diplomacySystem = initDiplomacySystem()
    #gameState.unitSystem = initUnitSystem()
    return gameState

proc save_game*( game: GameState ) = discard

proc load_game*(): GameState = discard

proc runGame*(
    game: GameState
) = 
    var consumedMouse = false
    let zoomLevel = getZoomLevelFromCameraZoom(game.mapSystem)
    clearBackground( BLACK )
    beginMode2D(game.mapSystem)
    game.mapSystem.drawMap()
    endMode2D()
    # draw UI and check if the mouse is consumed by the UI
    # ...
    # ...
    # ...
    
    consumedMouse = updateUserMapInteraction(game.mapSystem, consumedMouse)
    
    # debug print the zoom level and fps and mouse position
    drawText(
        "Zoom Level: " & $zoomLevel,
        10, 10, 20, GREEN
    )
    drawText(
        "FPS: " & $getFPS(),
        10, 40, 20, GREEN
    )
    drawText(
        "Mouse: " & $getMousePosition(),
        10, 70, 20, GREEN
    )
    drawText(
        "KRAFT: " & $game.diplomacySystem.getPlayerFaction().kraft,
        10, 100, 20, GREEN
    )
