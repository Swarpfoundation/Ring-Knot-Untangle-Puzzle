import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(environment.levelPack.levels, id: \.id) { level in
                        LevelCard(
                            level: level,
                            unlocked: environment.isUnlocked(level.id),
                            record: environment.progress.records[level.id]
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Select Level")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LevelCard: View {
    let level: Level
    let unlocked: Bool
    let record: LevelRecord?

    var body: some View {
        NavigationLink(value: HomeRoute.game(level.id)) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: unlocked
                                    ? [Color(red: 0.18, green: 0.20, blue: 0.27), Color(red: 0.10, green: 0.11, blue: 0.16)]
                                    : [Color(red: 0.08, green: 0.09, blue: 0.12), Color(red: 0.05, green: 0.06, blue: 0.09)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 96)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(borderColor, lineWidth: 1)
                        )
                    if unlocked {
                        VStack(spacing: 4) {
                            Text("\(level.id)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            if record?.completed == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.35))
                            }
                        }
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.gray)
                    }
                }
                Text(level.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(unlocked ? .white : .gray)
                    .lineLimit(1)
                if let best = record?.bestMoveCount {
                    Text("Best \(best)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(accessibilityLabel)
    }

    private var borderColor: Color {
        unlocked ? Color.white.opacity(0.08) : Color.white.opacity(0.04)
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["Level \(level.id) — \(level.name)"]
        if !unlocked { parts.append("Locked") }
        if record?.completed == true { parts.append("Completed") }
        if let best = record?.bestMoveCount { parts.append("Best moves \(best)") }
        return parts.joined(separator: ", ")
    }
}
