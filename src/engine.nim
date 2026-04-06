import std/options
import raylib
import gamestate
import textures

type
    
    EngineMode* = enum
        MainMenu,
        Playing,
        Paused

    Engine* = ref object
        isRunning: bool
        currentGame: Option[GameState]
        mode: EngineMode

proc getEngine*(): Engine =
    var engine {.global.}: Option[Engine] = none(Engine)
    if engine.isSome: return engine.get() # true most of the time, so happy path upfront
    if engine.isNone: 
        block INIT_ENGINE: 
            var e = Engine()
            initWindow( getScreenWidth(), getScreenHeight(), "Nim Raylib Example" )
            setTargetFPS( 60 )
            loadTileTextures()
            e.isRunning = true
            e.mode = EngineMode.Playing
            e.currentGame = some(newGameState())
            engine = some(e)
            return engine.get()
    raise newException(
        ValueError, 
        """
            Failed to get engine in getEngine.
            This should never happen, except we fail to initilize the engine at the start of the program.
        """
    )

proc endEngine*(engine: Engine) = engine.isRunning = false

proc runEngineLoop*(engine: Engine) = 
    while engine.isRunning:
        beginDrawing()
        case engine.mode:
        of EngineMode.MainMenu:
            drawText( "Main Menu", 190, 200, 20, LIGHTGRAY )
        of EngineMode.Playing:
            runGame(engine.currentGame.get())
        of EngineMode.Paused:
            drawText( "Paused", 190, 200, 20, LIGHTGRAY )    
        endDrawing()
        engine.isRunning = not windowShouldClose()

proc cleanupEngineBeforeProgrammExit*(engine: Engine) =
    unloadTileTextures()
    closeWindow()