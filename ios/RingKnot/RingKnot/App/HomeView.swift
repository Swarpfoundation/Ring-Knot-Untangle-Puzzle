import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.09),
                    Color(red: 0.10, green: 0.06, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                MarkView()
                    .frame(width: 168, height: 168)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("RING KNOT")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(.white)
                    Text("Untangle the puzzle")
                        .font(.callout)
                        .foregroundStyle(.gray)
                }

                Spacer()

                NavigationLink(value: HomeRoute.levelSelect) {
                    Text("Play")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.65, blue: 0.35),
                                    Color(red: 0.78, green: 0.40, blue: 0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .accessibilityLabel("Play. Opens the level select screen.")
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .levelSelect:
                LevelSelectView()
            case .game(let id):
                if let level = environment.levelPack.levels.first(where: { $0.id == id }) {
                    GameView(level: level)
                } else {
                    Text("Missing level \(id)")
                }
            }
        }
    }
}

enum HomeRoute: Hashable {
    case levelSelect
    case game(Int)
}

private struct MarkView: View {
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
