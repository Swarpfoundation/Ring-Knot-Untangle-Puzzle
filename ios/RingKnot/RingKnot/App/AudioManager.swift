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
    private let userDefaults: UserDefaults
    private let enabledKey = "com.swarpfoundation.ringknot.audio.enabled"

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: enabledKey) == nil {
            userDefaults.set(true, forKey: enabledKey)
        }
        configureSession()
        if sessionReady { preloadPools() }
    }

    var isEnabled: Bool {
        get { userDefaults.bool(forKey: enabledKey) }
        set { userDefaults.set(newValue, forKey: enabledKey) }
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
