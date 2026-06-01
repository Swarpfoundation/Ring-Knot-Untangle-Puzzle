import Foundation

/// Presentation-only derivations from level data. These do not invent or alter
/// level content — par is the solution length and the difficulty band is mapped
/// from the existing `difficulty` metadata in the level pack.
extension Level {
    /// Target number of moves: one per solution step (every ring is removed once).
    var parMoveCount: Int { solution.count }

    /// Human-facing difficulty band derived from the level's `difficulty` value
    /// (the pack uses 1...8). Falls back to ring/solution size if needed.
    var difficultyLabel: String {
        let score = difficulty > 0 ? difficulty : Int(ceil(Double(solution.count) / 2.5))
        switch score {
        case ...2: return "Easy"
        case 3...4: return "Medium"
        case 5...6: return "Hard"
        default: return "Expert"
        }
    }
}
