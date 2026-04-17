import std/options
import std/tables
import raylib

const PIXELS_PER_TILE* = 32
const SPAWN_TIME* = 3.0

type

    TileKind* = enum
        Grass, Mountain, Water, Spawn

    ChunkKind* = enum
        Grass, Mountain, Water, Spawn

    ZoomLevel* = enum
        VERY_CLOSE, CLOSE, DEFAULT, FAR, VERY_FAR

    DamageCategory* = enum
        Light, Medium, Heavy

    VisualKind* = enum
        Circle,
        Rect,
        Sprite

    BuildingKind* = enum
        Bunker

    Building* = object
        kind*: BuildingKind
        position*: Vector2
        health*: int
        maxHealth*: int
        alive*: bool
        factionIndex*: int
        occupantIndices*: seq[int]
        maxOccupants*: int
        currentChunk*: int
        rotation*: float

    # block TILE:
    Tile* = object # einzelnes Quadrat auf der Map, Position in Pixeln
        x*: int
        y*: int
        passable*: bool
        kind*: TileKind
        textureKey*: string

    # block CHUNK:
    Chunk* = object # Quadrat aus Tiles, dient Gameplay (Map-Kontrolle) und Performance (AI, Pathfinding)
        x*: int # Position in Pixeln
        y*: int
        kind*: ChunkKind
        passable*: bool
        currentOwner*: int  # -1 = no owner, otherwise faction index
        spawnForFaction*: int  # -1 = kein Spawn, sonst Fraktions-Index
        unitIndices*: seq[int] # welche Units gerade auf diesem Chunk sind
        tiles*: seq[Tile]
        kraftBonusOnCapture*: int  # 0 = kein einmaliger Bonus
        kraftBonusClaimed*: bool   # true wenn der einmalige Bonus schon vergeben wurde
        kraftPerSecond*: int       # 0 = kein fortlaufender Bonus

    # block MAP:
    Map* = object # quadratische Map aus Chunks, jeder Chunk aus Tiles
        mapSizeInChunks*: int
        chunkSizeInTiles*: int
        chunkSizePixels*: int      # chunkSizeInTiles * PIXELS_PER_TILE
        mapSizePixels*: int        # mapSizeInChunks * chunkSizePixels
        chunks*: seq[Chunk] # index = chunkX * mapSizeInChunks + chunkY

    # block UNIT:
    UnitDef* = object # Template fuer einen Einheitentyp (Soldat, Panzer, etc.)
        name*: string
        baseHealth*: int
        baseSpeed*: float
        baseArmor*: int
        visualKind*: VisualKind
        radius*: float
        width*: float
        height*: float
        damageCategory*: DamageCategory
        attackRange*: float
        attackDamage*: int
        attackCooldown*: float
        explosionRadiusHeavy*: float
        explosionRadiusMedium*: float
        explosionRadiusLight*: float
        kraftCost*: int  # Kosten in Kraft zum Spawnen
        texturePathRed*: string  # Pfad zur Textur fuer rote Fraktion
        texturePathBlue*: string  # Pfad zur Textur fuer blaue Fraktion
        texturePathNeutral*: string  # Pfad zur Textur wenn kein Besitzer (Emplacement ohne Crew)
        canTransport*: bool
        maxPassengers*: int
        isEmplacement*: bool
        crewSlots*: int
        canBeTowed*: bool
        handPushSpeed*: float
        deadTexturePath*: string

    Unit* = object # eine konkrete Einheit auf der Map
        definition*: UnitDef
        factionIndex*: int
        position*: Vector2
        health*: int
        alive*: bool
        targetPosition*: Option[Vector2]
        finalPosition*: Option[Vector2]
        path*: seq[int]       # chunk indices
        currentChunk*: int    # chunk index
        attackTimer*: float
        idleTimer*: float     # wie lange die Unit schon idle ist (Sekunden)
        rotation*: float      # Blickrichtung in Grad (0 = nach oben)
        shootPauseTimer*: float  # Movement-Pause nach Schuss
        passengerIndices*: seq[int]  # Indices der Soldaten in diesem Transporter
        inTransportOf*: int  # Index des Transporters in dem diese Unit sitzt, -1 = frei
        crewIndices*: seq[int]  # Indices der Soldaten die dieses Geschuetz besetzen
        towedByUnit*: int  # Index des LKWs der dieses Geschuetz zieht, -1 = frei
        towingEmplacement*: int  # Index des Geschuetzes das dieser LKW zieht, -1 = nichts
        towTarget*: int  # Index des Geschuetzes zu dem der LKW faehrt um anzukoppeln, -1 = keins
        assignedEmplacement*: int  # Index des Geschuetzes an dem dieser Soldat sitzt, -1 = frei
        inBuilding*: int  # Index des Buildings in dem diese Unit sitzt, -1 = frei

    # block PROJECTILE:
    Projectile* = object
        position*: Vector2
        targetPosition*: Vector2
        speed*: float
        damage*: int
        sourceDefIndex*: int  # index in unitDefs, fuer Explosions-Radien
        alive*: bool

    # block EXPLOSION:
    Explosion* = object
        position*: Vector2
        radiusHeavy*: float
        radiusMedium*: float
        radiusLight*: float
        damage*: int
        currentRadius*: float
        timer*: float
        maxTimer*: float
        damageApplied*: bool

    # block EFFECT:
    Effect* = object  # stationaer (Feuer)
        position*: Vector2
        radius*: float
        timer*: float
        maxTimer*: float

    SmokeParticle* = object  # driftet weg von Quelle
        position*: Vector2
        velocity*: Vector2
        radius*: float
        timer*: float
        maxTimer*: float

    # block DEBRIS:
    Debris* = object  # persistent: Leiche (Circle) oder Schrott (Rect)
        position*: Vector2
        visualKind*: VisualKind
        radius*: float   # fuer Circle
        width*: float    # fuer Rect
        height*: float   # fuer Rect
        rotation*: float # zufaellige Rotation beim Tod
        textureKey*: string # Sprite-Pfad fuer tote Einheit
        burnTimer*: float  # wie lange es noch brennt (0 = kein Feuer)
        fireFrame*: int    # 0 oder 1, wechselt fuer Animation
        fireAnimTimer*: float  # Timer fuer Frame-Wechsel

    # block TROOP:
    TroopEntry* = object
        unitDefIndex*: int
        count*: int

    TroopDef* = object
        name*: string
        kraftCost*: int
        entries*: seq[TroopEntry]

    # block SPAWN_QUEUE:
    SpawnRequest* = object
        unitDefIndex*: int
        factionIndex*: int
        spawnChunkIndex*: int  # auf welchem Spawn-Chunk erscheint die Unit
        timer*: float  # Countdown bis Spawn

    TroopSpawnRequest* = object
        troopDefIndex*: int
        factionIndex*: int
        spawnChunkIndex*: int
        timer*: float

    # block GOALS:
    GoalKind* = enum
        Attack, Defend

    FactionGoal* = object
        targetChunk*: int
        kind*: GoalKind
        priority*: int  # hoeher = wichtiger
        assignedUnits*: seq[int]  # unit indices

    # block STRATEGY:
    StrategyMode* = enum
        LastStand,        # alles zum Spawn zurueckziehen
        AllInAttack,      # alle Units zum Feind, kein Halten
        Frontline,        # defensive Linie, Ueberschuss sammeln
        OneAttackGroup,   # eine Angriffsgruppe formt sich
        TwoAttackGroups,  # zwei Gruppen, zwei Ziele
        Probing,          # kleine Gruppen testen den Feind
        FastControl,      # einzelne Units schwärmen aus, Chunks erobern
        Stosstrupp        # schnelle Gruppe greift gezielt an

    # block FACTION:
    Faction* = object
        name*: string
        color*: Color
        kraft*: int # einzige Ressource, wird fuer alles ausgegeben
        spawnQueue*: seq[SpawnRequest]
        troopSpawnQueue*: seq[TroopSpawnRequest]
        goals*: seq[FactionGoal]
        aiControlled*: bool
        aiSpawnTimer*: float
        aiThinkTimer*: float
        activeStrategy*: StrategyMode
        defeated*: bool

    # block GAME_STATE:
    GameState* = object
        # map
        map*: Map
        camera*: Camera2D
        textures*: Table[string, Texture2D]
        # units
        units*: seq[Unit]
        unitDefs*: seq[UnitDef]
        troopDefs*: seq[TroopDef]
        selectedUnits*: seq[int]
        # combat
        projectiles*: seq[Projectile]
        explosions*: seq[Explosion]
        # factions
        factions*: seq[Faction]
        # effects
        effects*: seq[Effect]
        smokeParticles*: seq[SmokeParticle]
        debris*: seq[Debris]
        # buildings
        buildings*: seq[Building]
        # input
        isDragging*: bool
        dragStart*: Vector2
        dragStartWorld*: Vector2
        # ui
        spawnMenuOpen*: bool
        uiHovered*: bool  # true wenn Maus ueber UI, verhindert Spielwelt-Klicks
        # victory
        gameOver*: bool
        winnerFactionIndex*: int  # -1 = kein Gewinner
        # kraft bonus
        kraftTickTimer*: float
