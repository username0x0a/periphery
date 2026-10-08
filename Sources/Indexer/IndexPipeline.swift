import Configuration
import Foundation
import Logger
import Shared
import SourceGraph

public struct IndexPipeline {
    private let plan: IndexPlan
    private let graph: SourceGraphMutex
    private let logger: ContextualLogger
    private let configuration: Configuration
    private let swiftVersion: SwiftVersion

    public init(plan: IndexPlan, graph: SourceGraphMutex, logger: ContextualLogger, configuration: Configuration, swiftVersion: SwiftVersion) {
        self.plan = plan
        self.graph = graph
        self.logger = logger
        self.configuration = configuration
        self.swiftVersion = swiftVersion
    }

    public func perform() throws -> Int {
        let scannedLOC = try SwiftIndexer(
            sourceFiles: plan.sourceFiles,
            graph: graph,
            logger: logger,
            configuration: configuration,
            swiftVersion: swiftVersion
        ).perform()

        try validateNoDeclarationConflicts()

        if !plan.plistPaths.isEmpty {
            try InfoPlistIndexer(
                infoPlistFiles: plan.plistPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xibPaths.isEmpty {
            try XibIndexer(
                xibFiles: plan.xibPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xcDataModelPaths.isEmpty {
            try XCDataModelIndexer(
                files: plan.xcDataModelPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        if !plan.xcMappingModelPaths.isEmpty {
            try XCMappingModelIndexer(
                files: plan.xcMappingModelPaths,
                graph: graph,
                logger: logger,
                configuration: configuration
            ).perform()
        }

        graph.withLock { $0.indexingComplete() }
        return scannedLOC
    }

    // MARK: - Private

    private func validateNoDeclarationConflicts() throws {
        let conflictingDeclarationsByUsr = graph.withLock { $0.conflictingDeclarationsByUsr }
        guard !conflictingDeclarationsByUsr.isEmpty else { return }

        // Files are indexed concurrently, so the declarations are sorted to produce a stable description.
        let conflicts = conflictingDeclarationsByUsr.keys.sorted().map { usr in
            let declarations = conflictingDeclarationsByUsr[usr, default: []]
                .sorted { $0.location < $1.location }
                .map { "  - \($0), declared in modules: \($0.location.file.modules.sorted())" }
            return (["USR '\(usr)':"] + declarations).joined(separator: "\n")
        }

        throw PeripheryError.declarationConflicts(conflicts)
    }
}
