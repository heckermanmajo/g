
type 

    UnitKind = enum
        Soldier,
        Tank
        
    Unit* = object
        id: UnitId
        health: int
        kind: UnitKind
        case kind:
        of Soldier:
            
        of Tank:
            armor: int
    

proc drawUnit*(unit: Unit) = 
    case unit.kind:
    of Soldier:
        drawCircle(100, 100, 20, RED)
    of Tank:
        drawRectangle(200, 200, 40, 40, BLUE)