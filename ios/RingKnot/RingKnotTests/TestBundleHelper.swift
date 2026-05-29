import Foundation
@testable import RingKnot

final class BundleAnchor {}

enum TestBundleHelper {
    static func loadShippedPack() throws -> LevelPack {
        var bundles: [Bundle] = [Bundle(for: BundleAnchor.self), Bundle.main]
        bundles.append(contentsOf: Bundle.allBundles)
        for bundle in bundles {
            if let url = bundle.url(forResource: "ring_unlock_level_pack_v1", withExtension: "json") {
                let data = try Data(contentsOf: url)
                return try LevelLoader.decode(data)
            }
        }
        throw LevelLoaderError.resourceMissing("ring_unlock_level_pack_v1.json (test bundle)")
    }
}
