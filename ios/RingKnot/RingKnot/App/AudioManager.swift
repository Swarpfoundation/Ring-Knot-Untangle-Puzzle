import AVFoundation
import Foundation

enum SoundEffect: String, CaseIterable {
    case buttonTap     = "sfx_button_tap"
    case ringSelect    = "sfx_ring_select"
    case ringInvalid   = "sfx_ring_invalid"
    case ringRelease   = "sfx_ring_release"
    case hint          = "sfx_hint"
    case levelComplete = "sfx_level_complete"
}

@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private let poolSize = 3
    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var cursor: [SoundEffect: Int] = [:]
    private var sessionReady = false

    /// Driven by `Preferences`. Defaults to on; flipping it off mutes all SFX
    /// immediately because `play(_:)` re-checks it on every call.
    var isEnabled: Bool = true

    private init() {
        configureSession()
        if sessionReady { preloadPools() }
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled, sessionReady,
              let pool = pools[effect],
              !pool.isEmpty else { return }
        let index = (cursor[effect] ?? 0) % pool.count
        cursor[effect] = index + 1
        let player = pool[index]
        if player.isPlaying { player.currentTime = 0 }
        player.play()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            sessionReady = true
        } catch {
            sessionReady = false
        }
    }

    private func preloadPools() {
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
                pools[effect] = []
                continue
            }
            var players: [AVAudioPlayer] = []
            for _ in 0..<poolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = 0.7
                    player.prepareToPlay()
                    players.append(player)
                }
            }
            pools[effect] = players
            cursor[effect] = 0
        }
    }
}
