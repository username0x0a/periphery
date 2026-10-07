import Configuration
import Foundation
import Indexer
import IndexStore
import Logger
import Shared
import SourceGraph
import SystemPackage

public final class SPMProjectDriver {
    private let pkg: SPM.Package
    private let configuration: Configuration
    private let logger: Logger

    public convenience init(configuration: Configuration, shell: Shell, logger: Logger) throws {
        if !configuration.schemes.isEmpty {
            throw PeripheryError.usageError("The --schemes option has no effect with Swift Package Manager projects.")
        }

        let pkg = SPM.Package(configuration: configuration, shell: shell, logger: logger)
        self.init(pkg: pkg, configuration: configuration, logger: logger)
    }

    init(pkg: SPM.Package, configuration: Configuration, logger: Logger) {
        self.pkg = pkg
        self.configuration = configuration
        self.logger = logger
    }
}

extension SPMProjectDriver: ProjectDriver {
    public func build() throws {
        if !configuration.skipBuild {
            if configuration.cleanBuild {
                try pkg.clean()
            }

            if configuration.outputFormat.supportsAuxiliaryOutput {
                let asterisk = logger.colorize("*", .boldGreen)
                logger.info("\(asterisk) Building...")
            }

            try pkg.build(additionalArguments: configuration.buildArguments)
        }
    }

    public func plan(logger: ContextualLogger) throws -> IndexPlan {
        let indexStorePaths: Set<FilePath> = if !configuration.indexStorePath.isEmpty {
            Set(configuration.indexStorePath)
        } else {
            [pkg.path.appending(".build/debug/index/store")]
        }

        // Load package description once and reuse it
        let description = try pkg.load()

        let excludedTestTargets = configuration.excludeTests ? testTargetNames(from: description) : []
        let collector = SourceFileCollector(
            indexStorePaths: indexStorePaths,
            excludedTestTargets: excludedTestTargets,
            logger: logger,
            configuration: configuration
        )
        let sourceFiles = try collector.collect()
        let resourceFiles = resourceFiles(from: description)

        return IndexPlan(
            sourceFiles: sourceFiles,
            xibPaths: resourceFiles[.interfaceBuilder, default: []],
            xcDataModelPaths: resourceFiles[.xcDataModel, default: []],
            xcMappingModelPaths: resourceFiles[.xcMappingModel, default: []]
        )
    }

    // MARK: - Private

    private func testTargetNames(from description: PackageDescription) -> Set<String> {
        description.targets.filter(\.isTestTarget).mapSet(\.name)
    }

    private static let resourceFileKinds: [ProjectFileKind] = [.interfaceBuilder, .xcDataModel, .xcMappingModel]

    private func resourceFiles(from description: PackageDescription) -> [ProjectFileKind: Set<FilePath>] {
        var files: [ProjectFileKind: Set<FilePath>] = [:]

        for target in description.targets {
            let targetPath = pkg.path.appending(target.path)

            // Explicitly declared resources.
            for resource in target.resources ?? [] {
                let resourceFilePath = FilePath(resource.path)
                let resourcePath: FilePath = resourceFilePath.isAbsolute
                    ? resourceFilePath
                    : targetPath.appending(resource.path)

                guard resourcePath.exists, let kind = resourceFileKind(for: resourcePath) else { continue }

                files[kind, default: []].insert(resourcePath)
            }

            // SwiftPM implicitly processes Interface Builder and Core Data resources found within the target
            // directory, even when they're not declared in the manifest. Such resources are not included in the
            // package description, so they must be discovered manually.
            for (kind, paths) in implicitResourceFiles(in: targetPath) {
                files[kind, default: []].formUnion(paths)
            }
        }

        return files
    }

    private func implicitResourceFiles(in targetPath: FilePath) -> [ProjectFileKind: Set<FilePath>] {
        var files: [ProjectFileKind: Set<FilePath>] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: targetPath.url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return files }

        for case let url as URL in enumerator {
            let path = FilePath(url.path)
            guard let kind = resourceFileKind(for: path) else { continue }

            files[kind, default: []].insert(path)

            // Data and mapping models are directory bundles, there's no need to descend into them.
            if kind != .interfaceBuilder {
                enumerator.skipDescendants()
            }
        }

        return files
    }

    private func resourceFileKind(for path: FilePath) -> ProjectFileKind? {
        guard let ext = path.extension?.lowercased() else { return nil }

        return Self.resourceFileKinds.first { $0.extensions.contains(ext) }
    }
}
