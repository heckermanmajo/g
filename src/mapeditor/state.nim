import raylib

import ../shared/types

type
    EditorMode* = enum
        MainMenu,
        NewMapDialog,
        LoadMapDialog,
        Editing,
        SaveDialog

    EditorTool* = enum
        ToolGrass,
        ToolMountain,
        ToolWater,
        ToolSpawn,
        ToolBonusOnCapture,
        ToolKraftPerSecond,
        ToolBuildings,
        ToolErase

    TextField* = object
        value*: string
        active*: bool

    EditorState* = object
        mode*: EditorMode
        map*: Map
        camera*: Camera2D
        uiHovered*: bool
        # editing
        activeTool*: EditorTool
        activeFaction*: int  # fuer Spawn-Tool, toggle 0/1
        activeBuilding*: BuildingKind
        bonusOnCaptureValue*: int
        kraftPerSecondValue*: int
        currentMapName*: string  # leer wenn neue Map noch nicht benannt
        # dialogs
        newMapSizeField*: TextField
        newMapChunkSizeField*: TextField
        saveNameField*: TextField
        bonusOnCaptureField*: TextField
        kraftPerSecondField*: TextField
        availableMaps*: seq[string]
        statusMessage*: string
        quitRequested*: bool
