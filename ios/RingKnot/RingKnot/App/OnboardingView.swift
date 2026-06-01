import SwiftUI

/// Short, game-specific first-run walkthrough. Shown once on first launch and
/// re-openable from Settings. Three pages, with Skip and a primary advance/Start
/// action. Respects Dynamic Type (scrolls) and Reduce Motion (no paging spring).
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let image: String
        let fallbackSymbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(id: 0,
             image: "ring_knot_home_hero",
             fallbackSymbol: "circle.dashed",
             title: "Rotate each ring to find its opening",
             body: "Most rings are open circles with one gap. Drag around a ring to roll it until the gap lines up with the way out."),
        Page(id: 1,
             image: "ring_knot_brand_mark",
             fallbackSymbol: "circle.circle",
             title: "Anchors hold the grid together",
             body: "Full closed rings are anchors — they don't move. The small metal clips show where each ring is caught by another."),
        Page(id: 2,
             image: "ring_knot_level_complete_emblem",
             fallbackSymbol: "lightbulb.circle",
             title: "Clear the clips, free the knot",
             body: "Line a ring's gap up with its exit, then pull it free past the clip. Clear the blockers first, then free the copper knot. Tap Hint for the next safe ring.")
    ]

    var body: some View {
        ZStack {
            BackgroundImage(name: "bg_menu_obsidian_portrait",
                            fallback: [Color(red: 0.05, green: 0.06, blue: 0.09),
                                       Color(red: 0.10, green: 0.06, blue: 0.04)])

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { onFinish() }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .accessibilityLabel("Skip the introduction")
                        .accessibilityIdentifier("onboarding.skip")
                }

                TabView(selection: $page) {
                    ForEach(pages) { page in
                        OnboardingPageView(
                            image: page.image,
                            fallbackSymbol: page.fallbackSymbol,
                            title: page.title,
                            message: page.body
                        )
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .transaction { txn in
                    if reduceMotion { txn.animation = nil }
                }

                Button(action: advance) {
                    Text(page == pages.count - 1 ? "Start" : "Next")
                        .font(.title3.weight(.semibold))
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
                .accessibilityLabel(page == pages.count - 1 ? "Start playing" : "Next page")
                .accessibilityIdentifier("onboarding.primary")
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    private func advance() {
        Haptics.shared.uiTap()
        AudioManager.shared.play(.buttonTap)
        if page < pages.count - 1 {
            if reduceMotion {
                page += 1
            } else {
                withAnimation { page += 1 }
            }
        } else {
            onFinish()
        }
    }
}

private struct OnboardingPageView: View {
    let image: String
    let fallbackSymbol: String
    let title: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Group {
                    if UIImage(named: image) != nil {
                        Image(image).resizable().scaledToFit()
                    } else {
                        Image(systemName: fallbackSymbol)
                            .resizable().scaledToFit()
                            .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.35))
                            .padding(40)
                    }
                }
                .frame(maxWidth: 240, maxHeight: 240)
                .padding(.top, 24)

                VStack(spacing: 14) {
                    Text(title)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 48)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}
