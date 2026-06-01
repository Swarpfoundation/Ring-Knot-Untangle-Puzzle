import Foundation

public enum LevelLoaderError: Error, CustomStringConvertible, Equatable {
    case resourceMissing(String)
    case malformedJSON(String)
    case duplicateLevelID(Int)
    case duplicateRingID(levelID: Int, ringID: String)
    case unknownDependency(levelID: Int, ringID: String, missing: String)
    case unknownSolutionRing(levelID: Int, ringID: String)
    case unknownDirection(levelID: Int, ringID: String, raw: String)
    case unknownCell(levelID: Int, ringID: String, raw: String)
    case missingCopper(levelID: Int)
    case dependencyCycle(levelID: Int, involving: [String])
    case unknownKind(levelID: Int, ringID: String, raw: String)
    case invalidGapAngle(levelID: Int, ringID: String, raw: Double)
    case invalidTolerance(levelID: Int, raw: Double)
    case unknownBodyType(levelID: Int, ringID: String, raw: String)
    case duplicateClipID(levelID: Int, clipID: String)
    case unknownClipOwner(levelID: Int, clipID: String, owner: String)
    case unknownClipBlocked(levelID: Int, clipID: String, blocked: String)
    case unknownInterlockRing(levelID: Int, interlockID: String, ringID: String)
    case unknownInterlockClip(levelID: Int, interlockID: String, clipID: String)

    public var description: String {
        switch self {
        case .resourceMissing(let name):
            return "Level resource missing: \(name)"
        case .malformedJSON(let reason):
            return "Malformed level JSON: \(reason)"
        case .duplicateLevelID(let id):
            return "Duplicate level id: \(id)"
        case .duplicateRingID(let levelID, let ringID):
            return "Duplicate ring id '\(ringID)' in level \(levelID)"
        case .unknownDependency(let levelID, let ringID, let missing):
            return "Ring \(ringID) in level \(levelID) requires missing piece '\(missing)'"
        case .unknownSolutionRing(let levelID, let ringID):
            return "Solution in level \(levelID) references unknown ring '\(ringID)'"
        case .unknownDirection(let levelID, let ringID, let raw):
            return "Ring \(ringID) in level \(levelID) has invalid direction '\(raw)'"
        case .unknownCell(let levelID, let ringID, let raw):
            return "Ring \(ringID) in level \(levelID) has invalid cell '\(raw)'"
        case .missingCopper(let levelID):
            return "Level \(levelID) has no copper ring"
        case .dependencyCycle(let levelID, let involving):
            let chain = involving.joined(separator: " -> ")
            return "Dependency cycle in level \(levelID): \(chain)"
        case .unknownKind(let levelID, let ringID, let raw):
            return "Ring \(ringID) in level \(levelID) has unknown kind '\(raw)'"
        case .invalidGapAngle(let levelID, let ringID, let raw):
            return "Ring \(ringID) in level \(levelID) has invalid initialGapAngle \(raw)"
        case .invalidTolerance(let levelID, let raw):
            return "Level \(levelID) has invalid alignmentToleranceDegrees \(raw)"
        case .unknownBodyType(let levelID, let ringID, let raw):
            return "Ring \(ringID) in level \(levelID) has unknown bodyType '\(raw)'"
        case .duplicateClipID(let levelID, let clipID):
            return "Duplicate clip id '\(clipID)' in level \(levelID)"
        case .unknownClipOwner(let levelID, let clipID, let owner):
            return "Clip '\(clipID)' in level \(levelID) has unknown ownerRingId '\(owner)'"
        case .unknownClipBlocked(let levelID, let clipID, let blocked):
            return "Clip '\(clipID)' in level \(levelID) blocks unknown ring '\(blocked)'"
        case .unknownInterlockRing(let levelID, let interlockID, let ringID):
            return "Interlock '\(interlockID)' in level \(levelID) references unknown ring '\(ringID)'"
        case .unknownInterlockClip(let levelID, let interlockID, let clipID):
            return "Interlock '\(interlockID)' in level \(levelID) references unknown clip '\(clipID)'"
        }
    }
}

public enum LevelLoader {
    public static let resourceName = "ring_unlock_level_pack_v1"

    public static func loadDefault(bundle: Bundle = .main) throws -> LevelPack {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LevelLoaderError.resourceMissing("\(resourceName).json")
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> LevelPack {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw LevelLoaderError.malformedJSON(error.localizedDescription)
        }
        guard let root = raw as? [String: Any] else {
            throw LevelLoaderError.malformedJSON("root not object")
        }
        let game = (root["game"] as? String) ?? "Ring Unlock"
        let version = (root["version"] as? String) ?? "0.0.0"
        guard let levelsRaw = root["levels"] as? [[String: Any]] else {
            throw LevelLoaderError.malformedJSON("missing levels array")
        }

        var seenLevelIDs = Set<Int>()
        var levels: [Level] = []
        for entry in levelsRaw {
            let level = try parseLevel(entry)
            if !seenLevelIDs.insert(level.id).inserted {
                throw LevelLoaderError.duplicateLevelID(level.id)
            }
            try validateLevel(level)
            levels.append(level)
        }
        return LevelPack(game: game, version: version, levels: levels)
    }

    private static func parseLevel(_ obj: [String: Any]) throws -> Level {
        guard let id = obj["id"] as? Int else {
            throw LevelLoaderError.malformedJSON("level missing id")
        }
        let name = (obj["name"] as? String) ?? "Level \(id)"
        let difficulty = (obj["difficulty"] as? Int) ?? 1
        guard let boardObj = obj["board"] as? [String: Any],
              let rows = boardObj["rows"] as? Int,
              let cols = boardObj["cols"] as? Int else {
            throw LevelLoaderError.malformedJSON("level \(id) missing board")
        }
        let board = Board(rows: rows, cols: cols)
        guard let piecesRaw = obj["pieces"] as? [[String: Any]] else {
            throw LevelLoaderError.malformedJSON("level \(id) missing pieces")
        }
        let solutionRaw = (obj["solution"] as? [[String: Any]]) ?? []

        // Optional per-level alignment tolerance; otherwise defaulted by band.
        var tolerance: Double? = nil
        if let raw = obj["alignmentToleranceDegrees"] as? NSNumber {
            let value = raw.doubleValue
            guard value > 0, value <= 90, value.isFinite else {
                throw LevelLoaderError.invalidTolerance(levelID: id, raw: value)
            }
            tolerance = value
        }

        var rings: [Ring] = []
        for piece in piecesRaw {
            rings.append(try parseRing(piece, levelID: id))
        }
        var steps: [SolutionStep] = []
        for step in solutionRaw {
            steps.append(try parseStep(step, levelID: id))
        }
        var clips: [BlockerClip] = []
        for clipRaw in (obj["clips"] as? [[String: Any]]) ?? [] {
            clips.append(try parseClip(clipRaw, levelID: id))
        }
        var interlocks: [Interlock] = []
        for lockRaw in (obj["interlocks"] as? [[String: Any]]) ?? [] {
            interlocks.append(try parseInterlock(lockRaw, levelID: id))
        }
        let abstractOnly = (obj["abstractOnly"] as? Bool) ?? false
        return Level(
            id: id,
            name: name,
            difficulty: difficulty,
            board: board,
            rings: rings,
            solution: steps,
            alignmentToleranceDegrees: tolerance,
            clips: clips,
            interlocks: interlocks,
            abstractOnly: abstractOnly
        )
    }

    private static func parseRing(_ obj: [String: Any], levelID: Int) throws -> Ring {
        guard let id = obj["id"] as? String else {
            throw LevelLoaderError.malformedJSON("level \(levelID) piece missing id")
        }
        guard let kindRaw = obj["kind"] as? String,
              let kind = RingKind(rawValue: kindRaw) else {
            throw LevelLoaderError.unknownKind(
                levelID: levelID,
                ringID: id,
                raw: (obj["kind"] as? String) ?? "<missing>"
            )
        }
        guard let cellRaw = obj["cell"] as? String,
              let cell = Cell.parse(cellRaw) else {
            throw LevelLoaderError.unknownCell(
                levelID: levelID,
                ringID: id,
                raw: (obj["cell"] as? String) ?? "<missing>"
            )
        }
        guard let dirRaw = obj["exitDirection"] as? String,
              let direction = Direction.parse(dirRaw) else {
            throw LevelLoaderError.unknownDirection(
                levelID: levelID,
                ringID: id,
                raw: (obj["exitDirection"] as? String) ?? "<missing>"
            )
        }
        let requires = (obj["requires"] as? [String]) ?? []
        // Optional explicit initial gap angle; otherwise derived deterministically
        // inside `Ring` so older packs without the field still load.
        var initialGapAngle: Double? = nil
        if let raw = obj["initialGapAngle"] as? NSNumber {
            let value = raw.doubleValue
            guard value.isFinite else {
                throw LevelLoaderError.invalidGapAngle(levelID: levelID, ringID: id, raw: value)
            }
            initialGapAngle = value
        }
        // Optional body type; defaults to openRing for backward compatibility.
        let bodyType: RingBodyType
        if let bodyRaw = obj["bodyType"] as? String {
            guard let parsed = RingBodyType(rawValue: bodyRaw) else {
                throw LevelLoaderError.unknownBodyType(levelID: levelID, ringID: id, raw: bodyRaw)
            }
            bodyType = parsed
        } else {
            bodyType = .openRing
        }
        // Optional removable override; otherwise derived from body type.
        let removable = obj["removable"] as? Bool
        return Ring(
            id: id,
            kind: kind,
            cell: cell,
            exitDirection: direction,
            requires: requires,
            initialGapAngleDegrees: initialGapAngle,
            bodyType: bodyType,
            removable: removable
        )
    }

    private static func parseClip(_ obj: [String: Any], levelID: Int) throws -> BlockerClip {
        guard let id = obj["id"] as? String else {
            throw LevelLoaderError.malformedJSON("level \(levelID) clip missing id")
        }
        guard let owner = obj["ownerRingId"] as? String else {
            throw LevelLoaderError.malformedJSON("level \(levelID) clip '\(id)' missing ownerRingId")
        }
        let angle = (obj["angleDegrees"] as? NSNumber)?.doubleValue ?? 0
        let material = (obj["material"] as? String).flatMap(ClipMaterial.init(rawValue:)) ?? .inherited
        let kind = (obj["kind"] as? String).flatMap(ClipKind.init(rawValue:)) ?? .blocker
        let blocks = (obj["blocksRingIds"] as? [String]) ?? []
        let widthScale = (obj["visualWidthScale"] as? NSNumber)?.doubleValue ?? 1.0
        let rotates = (obj["rotatesWithOwner"] as? Bool) ?? true
        return BlockerClip(
            id: id,
            ownerRingId: owner,
            angleDegrees: angle,
            material: material,
            kind: kind,
            blocksRingIds: blocks,
            visualWidthScale: widthScale,
            rotatesWithOwner: rotates
        )
    }

    private static func parseInterlock(_ obj: [String: Any], levelID: Int) throws -> Interlock {
        guard let id = obj["id"] as? String else {
            throw LevelLoaderError.malformedJSON("level \(levelID) interlock missing id")
        }
        guard let blocker = obj["blockerRingId"] as? String,
              let blocked = obj["blockedRingId"] as? String,
              let clip = obj["blockerClipId"] as? String else {
            throw LevelLoaderError.malformedJSON("level \(levelID) interlock '\(id)' missing references")
        }
        let contact = (obj["contactAngleDegrees"] as? NSNumber)?.doubleValue ?? 0
        let description = (obj["description"] as? String) ?? ""
        return Interlock(
            id: id,
            blockerRingId: blocker,
            blockedRingId: blocked,
            blockerClipId: clip,
            contactAngleDegrees: contact,
            description: description
        )
    }

    private static func parseStep(_ obj: [String: Any], levelID: Int) throws -> SolutionStep {
        guard let id = obj["id"] as? String else {
            throw LevelLoaderError.malformedJSON("level \(levelID) solution step missing id")
        }
        guard let dragRaw = obj["drag"] as? String,
              let direction = Direction.parse(dragRaw) else {
            throw LevelLoaderError.unknownDirection(
                levelID: levelID,
                ringID: id,
                raw: (obj["drag"] as? String) ?? "<missing>"
            )
        }
        return SolutionStep(ringId: id, direction: direction)
    }

    private static func validateLevel(_ level: Level) throws {
        var ringIDs = Set<String>()
        for ring in level.rings {
            if !ringIDs.insert(ring.id).inserted {
                throw LevelLoaderError.duplicateRingID(levelID: level.id, ringID: ring.id)
            }
        }
        for ring in level.rings {
            for dep in ring.requires where !ringIDs.contains(dep) {
                throw LevelLoaderError.unknownDependency(
                    levelID: level.id,
                    ringID: ring.id,
                    missing: dep
                )
            }
        }
        for step in level.solution where !ringIDs.contains(step.ringId) {
            throw LevelLoaderError.unknownSolutionRing(levelID: level.id, ringID: step.ringId)
        }
        if !level.rings.contains(where: { $0.kind == .copper }) {
            throw LevelLoaderError.missingCopper(levelID: level.id)
        }
        // Clip referential integrity: owner + blocked rings must exist; ids unique.
        var clipIDs = Set<String>()
        for clip in level.clips {
            if !clipIDs.insert(clip.id).inserted {
                throw LevelLoaderError.duplicateClipID(levelID: level.id, clipID: clip.id)
            }
            if !ringIDs.contains(clip.ownerRingId) {
                throw LevelLoaderError.unknownClipOwner(
                    levelID: level.id, clipID: clip.id, owner: clip.ownerRingId)
            }
            for blocked in clip.blocksRingIds where !ringIDs.contains(blocked) {
                throw LevelLoaderError.unknownClipBlocked(
                    levelID: level.id, clipID: clip.id, blocked: blocked)
            }
        }
        // Interlock referential integrity: rings + clip must exist.
        for lock in level.interlocks {
            for ringRef in [lock.blockerRingId, lock.blockedRingId] where !ringIDs.contains(ringRef) {
                throw LevelLoaderError.unknownInterlockRing(
                    levelID: level.id, interlockID: lock.id, ringID: ringRef)
            }
            if !clipIDs.contains(lock.blockerClipId) {
                throw LevelLoaderError.unknownInterlockClip(
                    levelID: level.id, interlockID: lock.id, clipID: lock.blockerClipId)
            }
        }
        try detectCycle(level: level)
    }

    private static func detectCycle(level: Level) throws {
        var color: [String: Int] = [:]
        for ring in level.rings { color[ring.id] = 0 }
        var trail: [String] = []
        func dfs(_ node: String) throws {
            color[node] = 1
            trail.append(node)
            guard let ring = level.ring(node) else { return }
            for dep in ring.requires {
                let c = color[dep] ?? 0
                if c == 1 {
                    if let cycleStart = trail.firstIndex(of: dep) {
                        let cycle = Array(trail[cycleStart...]) + [dep]
                        throw LevelLoaderError.dependencyCycle(
                            levelID: level.id,
                            involving: cycle
                        )
                    }
                    throw LevelLoaderError.dependencyCycle(levelID: level.id, involving: [dep])
                } else if c == 0 {
                    try dfs(dep)
                }
            }
            color[node] = 2
            trail.removeLast()
        }
        for ring in level.rings where color[ring.id] == 0 {
            try dfs(ring.id)
        }
    }
}
