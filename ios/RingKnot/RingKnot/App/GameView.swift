import SpriteKit
import SwiftUI

struct GameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @StateObject private var controller = GameController()
    @State private var currentLevel: Level
    /// nil = no tutorial; 0 = "rotate to align"; 1 = "pull it out"; 2 = "clear blockers".
    @State private var tutorialStep: Int?

    init(level: Level) {
        _currentLevel = State(initialValue: level)
    }

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_gameplay_obsidian_portrait",
                            fallback: [Color.black, Color(red: 0.04, green: 0.05, blue: 0.07)])

            VStack(spacing: 0) {
                HUDBar(
                    levelID: currentLevel.id,
                    name: currentLevel.name,
                    moves: controller.moves,
                    onBack: {
                        Haptics.shared.uiTap()
                        AudioManager.shared.play(.buttonTap)
                        dismiss()
                    },
                    onRestart: {
                        Haptics.shared.uiTap()
                        AudioManager.shared.play(.buttonTap)
                        controller.restart()
                        restartTutorialIfNeeded()
                    },
                    onHint: {
                        Haptics.shared.uiTap()
                        AudioManager.shared.play(.hint)
                        controller.hint()
                    }
                )
                ZStack(alignment: .top) {
                    SpriteView(scene: controller.scene(for: currentLevel, reduceMotion: reduceMotion))
                        .ignoresSafeArea(edges: .bottom)
                        .accessibilityElement()
                        .accessibilityLabel(controller.boardAccessibilitySummary)
                        .accessibilityIdentifier("game.board")
                        .accessibilityAction(named: "Rotate ring to opening") {
                            controller.rotateSuggestedRingToExit()
                        }
                        .accessibilityAction(named: "Show Hint") {
                            AudioManager.shared.play(.hint)
                            controller.hint()
                        }
                        .accessibilityAction(named: "Restart Level") {
                            controller.restart()
                            restartTutorialIfNeeded()
                        }

                    if let step = tutorialStep {
                        TutorialPanel(step: step)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("tutorial.panel")
                    }
                }
            }

            if controller.didComplete, let info = controller.completion {
                CompletionOverlay(
                    info: info,
                    onNext: advanceToNextLevel,
                    onReplay: {
                        Haptics.shared.uiTap()
                        AudioManager.shared.play(.buttonTap)
                        controller.restart()
                        restartTutorialIfNeeded()
                    },
                    onLevelSelect: {
                        Haptics.shared.uiTap()
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
            controller.scene(for: currentLevel, reduceMotion: reduceMotion)
            startTutorialIfNeeded()
        }
        .onChange(of: controller.tutorialAlignedTick) { _, _ in
            // The highlighted ring's gap lined up: move from "rotate" to "pull".
            if tutorialStep == 0 { tutorialStep = 1 }
        }
        .onChange(of: controller.clearedCount) { _, count in
            advanceTutorial(clearedCount: count)
        }
        .onChange(of: controller.didComplete) { _, done in
            if done { finishTutorial() }
        }
    }

    // MARK: - Level navigation

    private func advanceToNextLevel() {
        Haptics.shared.uiTap()
        AudioManager.shared.play(.buttonTap)
        guard let next = environment.nextLevelID(after: currentLevel.id),
              let nextLevel = environment.levelPack.levels.first(where: { $0.id == next }) else {
            dismiss()
            return
        }
        finishTutorial()
        currentLevel = nextLevel
        controller.replaceLevel(with: nextLevel, reduceMotion: reduceMotion)
    }

    // MARK: - Tutorial

    private func startTutorialIfNeeded() {
        guard currentLevel.id == 1, !preferences.level1TutorialCompleted else { return }
        tutorialStep = 0
        controller.setTutorialGuidance(active: true)
    }

    private func restartTutorialIfNeeded() {
        guard currentLevel.id == 1, !preferences.level1TutorialCompleted else { return }
        tutorialStep = 0
        controller.setTutorialGuidance(active: true)
    }

    private func advanceTutorial(clearedCount: Int) {
        guard tutorialStep != nil else { return }
        if clearedCount >= 2 {
            finishTutorial()
        } else if clearedCount == 1 {
            // First ring is out — teach that some rings are blocked.
            tutorialStep = 2
        }
    }

    private func finishTutorial() {
        guard tutorialStep != nil else { return }
        tutorialStep = nil
        controller.setTutorialGuidance(active: false)
        if currentLevel.id == 1 {
            preferences.level1TutorialCompleted = true
        }
    }
}

private struct TutorialPanel: View {
    let step: Int

    private var text: String {
        switch step {
        case 0:  return "Rotate the ring until the opening faces the arrow."
        case 1:  return "Now pull it out through the gap."
        default: return "Some rings are blocked. Clear them first, then free the copper knot."
        }
    }

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.92))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 24)
            .accessibilityLabel("Tutorial. \(text)")
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
                // No `children: .combine` wrapper here: combining while a child
                // also carries an identifier surfaces the id on two elements.
                // The identifier lives on this single leaf and its label stays
                // exactly the count ("0", "1", …) for both VoiceOver and tests.
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
                if UIImage(named: name) != nil {
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
    let info: CompletionInfo
    let onNext: () -> Void
    let onReplay: () -> Void
    let onLevelSelect: () -> Void

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_completion_dark_burst",
                            fallback: [Color.black.opacity(0.65), .clear])
                .opacity(0.92)
            VStack(spacing: 16) {
                Group {
                    if UIImage(named: "ring_knot_level_complete_emblem") != nil {
                        Image("ring_knot_level_complete_emblem")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 76))
                            .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.35))
                    }
                }
                Text("Level Complete")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                if info.isNewBest {
                    Text("New Best!")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.4))
                        .accessibilityIdentifier("completion.newBest")
                }

                VStack(spacing: 6) {
                    statRow("Moves", "\(info.moves)", id: "completion.moves")
                    statRow("Par", "\(info.par)", id: "completion.par")
                    statRow("Best", "\(info.best)", id: "completion.best")
                }
                .padding(.vertical, 4)

                VStack(spacing: 10) {
                    if info.isLastLevel {
                        Text("All Levels Complete")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 0.35),
                                                        Color(red: 0.78, green: 0.40, blue: 0.18)],
                                               startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .accessibilityIdentifier("completion.allComplete")
                    } else {
                        primaryButton("Next Level", action: onNext, id: "completion.next")
                    }
                    HStack(spacing: 12) {
                        secondaryButton("Replay", action: onReplay, id: "completion.replay")
                        secondaryButton("Level Select", action: onLevelSelect, id: "completion.levelSelect")
                    }
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.94))
            )
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .contain)
    }

    private func statRow(_ label: String, _ value: String, id: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.gray)
            Spacer()
            Text(value).foregroundStyle(.white).font(.body.monospacedDigit().weight(.semibold))
        }
        .font(.body)
        .frame(maxWidth: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
        .accessibilityIdentifier(id)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void, id: String) -> some View {
        Button(title, action: action)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 0.35),
                                        Color(red: 0.78, green: 0.40, blue: 0.18)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .accessibilityIdentifier(id)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void, id: String) -> some View {
        Button(title, action: action)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(id)
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
                    bridgeButton("bridge.nextMove") { controller.bridgePerformNextSolutionMove() }
                    bridgeButton("bridge.invalidMove") { controller.bridgePerformInvalidMove() }
                    bridgeButton("bridge.rotateAligned") { controller.bridgeRotateNextSolutionRingToAligned() }
                    bridgeButton("bridge.rotateMisaligned") { controller.bridgeRotateSelectedRingToMisaligned() }
                    bridgeButton("bridge.tryRelease") { controller.bridgeTryReleaseNextSolutionRing() }
                    bridgeButton("bridge.rotationMove") { controller.bridgePerformNextSolutionMoveWithRotation() }
                }
                .padding(.bottom, 4)
            }
            .allowsHitTesting(true)
        }
    }

    private func bridgeButton(_ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Color.clear.frame(width: 30, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(id)
    }
}
#endif
