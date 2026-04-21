import std/tables
import std/heapqueue

import ../shared/types

type AStarNode = object
    chunkIdx: int
    f: float

proc `<`(a, b: AStarNode): bool = a.f < b.f

proc findPath*(game: GameState, fromChunk, toChunk: int): seq[int] =
    if fromChunk == toChunk: return @[]
    let chunksPerSide = game.map.mapSizeInChunks

    var openSet: HeapQueue[AStarNode]
    var cameFrom: Table[int, int]
    var gScore: Table[int, float]

    gScore[fromChunk] = 0.0

    let targetChunkX = toChunk div chunksPerSide
    let targetChunkY = toChunk mod chunksPerSide
    let startChunkX = fromChunk div chunksPerSide
    let startChunkY = fromChunk mod chunksPerSide
    let initialHeuristic = max(abs(targetChunkX - startChunkX).float, abs(targetChunkY - startChunkY).float)
    openSet.push(AStarNode(chunkIdx: fromChunk, f: initialHeuristic))

    let directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    while openSet.len > 0:
        let current = openSet.pop()
        if current.chunkIdx == toChunk:
            var path: seq[int] = @[]
            var currentChunkIdx = toChunk
            while currentChunkIdx != fromChunk:
                path.add(currentChunkIdx)
                currentChunkIdx = cameFrom[currentChunkIdx]
            for i in 0 ..< path.len div 2:
                let tmp = path[i]
                path[i] = path[path.len - 1 - i]
                path[path.len - 1 - i] = tmp
            return path

        let currentX = current.chunkIdx div chunksPerSide
        let currentY = current.chunkIdx mod chunksPerSide
        for (dx, dy) in directions:
            let neighborX = currentX + dx
            let neighborY = currentY + dy
            if neighborX < 0 or neighborY < 0 or neighborX >= chunksPerSide or neighborY >= chunksPerSide: continue
            let neighborIdx = neighborX * chunksPerSide + neighborY
            if not game.map.chunks[neighborIdx].passable: continue
            let moveCost = if dx != 0 and dy != 0: 1.414 else: 1.0
            let tentative = gScore[current.chunkIdx] + moveCost
            if neighborIdx notin gScore or tentative < gScore[neighborIdx]:
                gScore[neighborIdx] = tentative
                cameFrom[neighborIdx] = current.chunkIdx
                let heuristicX = abs(targetChunkX - (neighborIdx div chunksPerSide)).float
                let heuristicY = abs(targetChunkY - (neighborIdx mod chunksPerSide)).float
                openSet.push(AStarNode(chunkIdx: neighborIdx, f: tentative + max(heuristicX, heuristicY)))

    return @[]
