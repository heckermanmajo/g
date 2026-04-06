import raylib
import engine

block:
    # here is the place to listen for the cmd args and decide what engine mode to start, etc.
    var engine: Engine = getEngine()
    runEngineLoop(engine)
    cleanupEngineBeforeProgrammExit(engine)
