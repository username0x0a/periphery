import ArgumentParser
import Foundation
import Shared

struct ClearCacheCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear-cache",
        abstract: "Clear Periphery's build cache"
    )

    func run() throws {
        let cachePath = try Constants.cachePath().string
        guard FileManager.default.fileExists(atPath: cachePath) else { return }

        try FileManager.default.removeItem(atPath: cachePath)
    }
}
