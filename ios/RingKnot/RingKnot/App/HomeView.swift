import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_menu_obsidian_portrait",
                            fallback: [
                                Color(red: 0.05, green: 0.06, blue: 0.09),
                                Color(red: 0.10, green: 0.06, blue: 0.04)
                            ])
            VStack(spacing: 22) {
                Spacer()
                BrandHero()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .accessibilityLabel("Ring Knot")
                VStack(spacing: 6) {
                    Text("RING KNOT")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(.white)
                    Text("Untangle the puzzle")
                        .font(.callout)
                        .foregroundStyle(.gray)
                }
                .accessibilityElement(children: .combine)
                Spacer()

                if environment.hasProgress, let target = environment.continueTargetID {
                    NavigationLink(value: HomeRoute.game(target)) {
                        primaryLabel("Continue", subtitle: "Level \(target)")
                    }
                    .accessibilityLabel("Continue. Resumes level \(target).")
                    .accessibilityIdentifier("home.continue")
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.shared.uiTap()
                        AudioManager.shared.play(.buttonTap)
                    })
                    .padding(.horizontal, 32)
                }

                NavigationLink(value: HomeRoute.levelSelect) {
                    if environment.hasProgress {
                        secondaryLabel("Level Select")
                    } else {
                        primaryLabel("Play", subtitle: nil)
                    }
                }
                .accessibilityLabel("Play. Opens the level select screen.")
                .accessibilityIdentifier("home.play")
                .simultaneousGesture(TapGesture().onEnded {
                    Haptics.shared.uiTap()
                    AudioManager.shared.play(.buttonTap)
                })
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HomeRoute.settings) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("home.settings")
            }
        }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .levelSelect:
                LevelSelectView()
            case .settings:
                SettingsView()
            case .game(let id):
                if let level = environment.levelPack.levels.first(where: { $0.id == id }) {
                    GameView(level: level)
                } else {
                    Text("Missing level \(id)")
                }
            }
        }
    }

    private func primaryLabel(_ title: String, subtitle: String?) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.caption).opacity(0.85)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.65, blue: 0.35),
                         Color(red: 0.78, green: 0.40, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .foregroundStyle(.white)
    }
}

enum HomeRoute: Hashable {
    case levelSelect
    case settings
    case game(Int)
}

struct BackgroundImage: View {
    let name: String
    let fallback: [Color]

    var body: some View {
        ZStack {
            if let _ = UIImage(named: name) {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: fallback, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
        }
    }
}

struct BrandHero: View {
    var body: some View {
        Group {
            if let _ = UIImage(named: "ring_knot_home_hero") {
                Image("ring_knot_home_hero")
                    .resizable()
                    .scaledToFit()
            } else {
                FallbackMark()
            }
        }
    }
}

private struct FallbackMark: View {
    var body: some View {
        ZStack {
            RingGlyph(color: Color(red: 0.72, green: 0.76, blue: 0.84), gap: 70, rotation: -.pi / 2)
                .offset(x: -22, y: -8)
            RingGlyph(color: Color(red: 0.72, green: 0.76, blue: 0.84), gap: 70, rotation: .pi / 2)
                .offset(x: 22, y: -8)
            RingGlyph(color: Color(red: 0.92, green: 0.60, blue: 0.28), gap: 60, rotation: 0)
                .offset(x: 0, y: 18)
        }
    }
}

private struct RingGlyph: View {
    let color: Color
    let gap: Double
    let rotation: Double

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 * 0.78
            let lineWidth = radius * 0.32
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var path = Path()
            let half = (gap * .pi / 180) / 2
            let start = rotation + half
            let end = rotation + (2 * .pi) - half
            path.addArc(
                center: center,
                radius: radius - lineWidth / 2,
                startAngle: .radians(start),
                endAngle: .radians(end),
                clockwise: false
            )
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }
}
