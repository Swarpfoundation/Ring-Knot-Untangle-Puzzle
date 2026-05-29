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
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HUDBar(
                    levelID: level.id,
                    name: level.name,
                    moves: controller.moves,
                    onRestart: { controller.restart() },
                    onHint: { controller.hint() }
                )
                SpriteView(scene: controller.scene(for: level, reduceMotion: reduceMotion))
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityLabel("Game board for level \(level.id)")
            }

            if controller.didComplete {
                CompletionOverlay(
                    moves: controller.moves,
                    nextLevelID: environment.nextLevelID(after: level.id),
                    onNext: {
                        guard let next = environment.nextLevelID(after: level.id),
                              let nextLevel = environment.levelPack.levels.first(where: { $0.id == next }) else {
                            dismiss()
                            return
                        }
                        controller.replaceLevel(with: nextLevel, reduceMotion: reduceMotion)
                    },
                    onMenu: { dismiss() }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Back to level select")
            }
        }
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
    let onRestart: () -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Level \(levelID)")
                    .font(.headline)
                    .foregroundStyle(.white)
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
            }
            Button(action: onHint) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.4))
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .accessibilityLabel("Hint — highlight next solvable ring")
            Button(action: onRestart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .accessibilityLabel("Restart level")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.black)
    }
}

private struct CompletionOverlay: View {
    let moves: Int
    let nextLevelID: Int?
    let onNext: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 16) {
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
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.07, green: 0.08, blue: 0.12))
            )
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
    }
}
