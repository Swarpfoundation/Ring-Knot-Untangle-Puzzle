import SpriteKit
import SwiftUI

struct GameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let level: Level

    @StateObject private var controller = GameController()

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_gameplay_obsidian_portrait",
                            fallback: [Color.black, Color(red: 0.04, green: 0.05, blue: 0.07)])

            VStack(spacing: 0) {
                HUDBar(
                    levelID: level.id,
                    name: level.name,
                    moves: controller.moves,
                    onBack: {
                        AudioManager.shared.play(.buttonTap)
                        dismiss()
                    },
                    onRestart: {
                        AudioManager.shared.play(.buttonTap)
                        controller.restart()
                    },
                    onHint: {
                        AudioManager.shared.play(.hint)
                        controller.hint()
                    }
                )
                SpriteView(scene: controller.scene(for: level, reduceMotion: reduceMotion))
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityLabel("Game board for level \(level.id)")
                    .accessibilityIdentifier("game.board")
            }

            if controller.didComplete {
                CompletionOverlay(
                    moves: controller.moves,
                    nextLevelID: environment.nextLevelID(after: level.id),
                    onNext: {
                        AudioManager.shared.play(.buttonTap)
                        guard let next = environment.nextLevelID(after: level.id),
                              let nextLevel = environment.levelPack.levels.first(where: { $0.id == next }) else {
                            dismiss()
                            return
                        }
                        controller.replaceLevel(with: nextLevel, reduceMotion: reduceMotion)
                    },
                    onMenu: {
                        AudioManager.shared.play(.buttonTap)
                        dismiss()
                    }
                )
                .accessibilityIdentifier("game.completion")
            }

            #if DEBUG
            TestBridgeOverlay(controller: controller)
            #endif
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            controller.bind(environment: environment)
            controller.scene(for: level, reduceMotion: reduceMotion)
        }
    }
}

private struct HUDBar: View {
    let levelID: Int
    let name: String
    let moves: Int
    let onBack: () -> Void
    let onRestart: () -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HUDIconButton(name: "ui_button_back",
                          systemFallback: "chevron.left",
                          tint: .white,
                          accessibilityLabel: "Back to level select",
                          identifier: "game.back",
                          action: onBack)
            VStack(alignment: .leading, spacing: 2) {
                Text("Level \(levelID)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("hud.levelNumber")
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Moves")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text("\(moves)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("hud.moves")
            }
            HUDIconButton(name: "ui_button_hint",
                          systemFallback: "lightbulb.fill",
                          tint: Color(red: 1.0, green: 0.82, blue: 0.4),
                          accessibilityLabel: "Hint — highlight next solvable ring",
                          identifier: "hud.hint",
                          action: onHint)
            HUDIconButton(name: "ui_button_restart",
                          systemFallback: "arrow.counterclockwise",
                          tint: .white,
                          accessibilityLabel: "Restart level",
                          identifier: "hud.restart",
                          action: onRestart)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.black)
    }
}

private struct HUDIconButton: View {
    let name: String
    let systemFallback: String
    let tint: Color
    let accessibilityLabel: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let _ = UIImage(named: name) {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: systemFallback)
                        .font(.title3)
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(6)
            .background(Color.white.opacity(0.06), in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}

private struct CompletionOverlay: View {
    let moves: Int
    let nextLevelID: Int?
    let onNext: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_completion_dark_burst",
                            fallback: [Color.black.opacity(0.65), .clear])
                .opacity(0.92)
            VStack(spacing: 16) {
                Group {
                    if let _ = UIImage(named: "ring_knot_level_complete_emblem") {
                        Image("ring_knot_level_complete_emblem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.35))
                    }
                }
                Text("Solved")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(moves) moves")
                    .font(.title3)
                    .foregroundStyle(.gray)
                HStack(spacing: 12) {
                    Button("Menu", action: onMenu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("completion.menu")
                    Button(nextLevelID == nil ? "Done" : "Next Level", action: onNext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.65, blue: 0.35),
                                    Color(red: 0.78, green: 0.40, blue: 0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .accessibilityIdentifier("completion.next")
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.92))
            )
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
private struct TestBridgeOverlay: View {
    let controller: GameController

    var body: some View {
        // Only present when launched under XCUITest (-uiTestBridge YES).
        let isTesting = ProcessInfo.processInfo.arguments.contains("-uiTestBridge")
        if isTesting {
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Button(action: { controller.bridgePerformNextSolutionMove() }) {
                        Color.clear.frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("bridge.nextMove")
                    Button(action: { controller.bridgePerformInvalidMove() }) {
                        Color.clear.frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("bridge.invalidMove")
                }
                .padding(.bottom, 4)
            }
            .allowsHitTesting(true)
        }
    }
}
#endif
