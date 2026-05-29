import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 16)
    ]

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_menu_obsidian_portrait",
                            fallback: [Color.black, Color(red: 0.06, green: 0.04, blue: 0.02)])
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(environment.levelPack.levels, id: \.id) { level in
                        LevelCard(
                            level: level,
                            unlocked: environment.isUnlocked(level.id),
                            record: environment.progress.records[level.id]
                        )
                        .accessibilityIdentifier("levelCard.\(level.id)")
                    }
                }
                .padding(20)
            }
            .accessibilityIdentifier("levelSelect.grid")
        }
        .navigationTitle("Select Level")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HomeRoute.settings) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("levelSelect.settings")
            }
        }
    }
}

private struct LevelCard: View {
    let level: Level
    let unlocked: Bool
    let record: LevelRecord?

    private var completed: Bool { record?.completed == true }

    var body: some View {
        NavigationLink(value: HomeRoute.game(level.id)) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(fillGradient)
                        .frame(height: 104)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(borderColor, lineWidth: completed ? 1.5 : 1)
                        )
                    if unlocked {
                        VStack(spacing: 3) {
                            Text("\(level.id)")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(level.difficultyLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.gray)
                            if completed {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
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
                Text(detailLine)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .simultaneousGesture(TapGesture().onEnded {
            if unlocked {
                Haptics.shared.uiTap()
                AudioManager.shared.play(.buttonTap)
            }
        })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(unlocked ? .isButton : [])
    }

    private var fillGradient: LinearGradient {
        let colors: [Color]
        if !unlocked {
            colors = [Color(red: 0.08, green: 0.09, blue: 0.12), Color(red: 0.05, green: 0.06, blue: 0.09)]
        } else if completed {
            colors = [Color(red: 0.20, green: 0.16, blue: 0.12), Color(red: 0.12, green: 0.10, blue: 0.08)]
        } else {
            colors = [Color(red: 0.18, green: 0.20, blue: 0.27), Color(red: 0.10, green: 0.11, blue: 0.16)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var borderColor: Color {
        if completed { return Color(red: 0.95, green: 0.65, blue: 0.35).opacity(0.45) }
        return unlocked ? Color.white.opacity(0.08) : Color.white.opacity(0.04)
    }

    /// Best when completed, otherwise the par target. Hidden for locked levels.
    private var detailLine: String {
        guard unlocked else { return " " }
        if let best = record?.bestMoveCount {
            return "Best \(best) · Par \(level.parMoveCount)"
        }
        return "Par \(level.parMoveCount)"
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["Level \(level.id), \(level.name)", level.difficultyLabel]
        if !unlocked {
            parts.append("Locked")
        } else if completed {
            parts.append("Completed")
        } else {
            parts.append("Unlocked")
        }
        parts.append("Par \(level.parMoveCount) moves")
        if let best = record?.bestMoveCount { parts.append("Best \(best) moves") }
        return parts.joined(separator: ", ")
    }
}
