import raylib


var grassTextures*: array[6, Texture2D]

proc loadTileTextures*() =
    ## called in engine.nim after initWindow()
    for i in 0..5:
        grassTextures[i] = loadTexture("res/tiles/gras" & $(i+1) & ".png")

proc unloadTileTextures*() =
    ## called in engine.nim before closeWindow()
    reset(grassTextures)
