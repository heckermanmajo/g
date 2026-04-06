import raylib
import share/share_types


type 


    DiplomacySystem* = ref object
        factions*: seq[Faction]


    Faction* = ref object
        id*: FactionId
        name*: string
        color*: Color
        kraft*: int # main resource for everything


proc initDiplomacySystem*(): DiplomacySystem =
    let diplomacySystem = DiplomacySystem(
        factions: @[
            Faction(
                id: 0,
                name: "Faction 1",
                color: RED,
                kraft: 100
            ),  
            Faction(
                id: 1,
                name: "Faction 2",
                color: BLUE,
                kraft: 100
            )
        ]
    )
    return diplomacySystem
    

proc getColor*(diplomacySystem: DiplomacySystem, factionId: FactionId): Color =
    if factionId.int32 >= diplomacySystem.factions.len or factionId.int32 < 0:
        raise newException(
            ValueError, 
            "Invalid faction id: " & $factionId
        )  
    return diplomacySystem.factions[factionId.int32].color


proc getPlayerFaction*(diplomacySystem: DiplomacySystem): Faction =
    return diplomacySystem.factions[0]