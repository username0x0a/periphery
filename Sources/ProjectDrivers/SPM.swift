import Configuration
import Extensions
import Foundation
import Logger
import Shared
import SystemPackage

public enum SPM {
    public static var isSupported: Bool {
        FilePath.current.appending("Package.swift").exists
    }

    public struct Package {
        public let path: FilePath = .current

        private let configuration: Configuration
        private let shell: Shell
        private let logger: Logger

        public init(configuration: Configuration, shell: Shell, logger: Logger) {
            self.configuration = configuration
            self.shell = shell
            self.logger = logger
        }

        public func clean() throws {
            try shell.exec(["swift", "package", "clean"])
        }

        public func build(additionalArguments: [String]) throws {
            // The swiftbuild build system (default since Swift 6.4) only writes the index store to the products
            // directory when indexing is explicitly enabled.
            let indexStoreFlags = ["--auto-index-store", "--enable-index-store", "--disable-index-store"]
            let indexStoreArguments = additionalArguments.contains(where: indexStoreFlags.contains)
                ? []
                : ["--enable-index-store"]
            try shell.exec(["swift", "build", "--build-tests"] + indexStoreArguments + additionalArguments)
        }

        /// The index store path for a debug build.
        ///
        /// The native build system, and the swiftbuild build system with indexing explicitly enabled, write the
        /// index store to `.build/debug/index/store`. When indexing is left in automatic mode (e.g. `swift build`
        /// or `swift test` without arguments), swiftbuild instead writes it to `.build/out`. If both exist, the most
        /// recently updated one is used.
        public var indexStorePath: FilePath {
            let productsStorePath = path.appending(".build/debug/index/store")
            let swiftBuildStorePath = path.appending(".build/out")
            let candidates = [productsStorePath, swiftBuildStorePath]
                .compactMap { storePath -> (FilePath, Date)? in
                    let unitsPath = storePath.appending("v5/units")
                    guard unitsPath.exists else { return nil }

                    let attributes = try? FileManager.default.attributesOfItem(atPath: unitsPath.string)
                    return (storePath, attributes?[.modificationDate] as? Date ?? .distantPast)
                }

            return candidates.max { $0.1 < $1.1 }?.0 ?? productsStorePath
        }

        public func load() throws -> PackageDescription {
            logger.contextualized(with: "spm:package").debug("Loading \(FilePath.current)")

            let jsonData: Data

            if let path = configuration.jsonPackageManifestPath {
                jsonData = try Data(contentsOf: path.url)
            } else {
                let jsonString = try shell.exec(["swift", "package", "describe", "--type", "json"])

                guard let data = jsonString.data(using: .utf8) else {
                    throw PeripheryError.packageError(message: "Failed to read swift package description.")
                }

                jsonData = data
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(PackageDescription.self, from: jsonData)
        }
    }
}

public struct PackageDescription: Decodable {
    public let targets: [Target]
}

public struct Target: Decodable {
    public let name: String
    public let type: String
    public let path: String
    public let resources: [Resource]?

    public var isTestTarget: Bool {
        type == "test"
    }
}

public struct Resource: Decodable {
    public let path: String
}
