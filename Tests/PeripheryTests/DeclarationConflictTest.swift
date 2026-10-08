import Configuration
@testable import Indexer
import Logger
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

final class DeclarationConflictTest: XCTestCase {
    func testThrowsForConflictingDeclarations() throws {
        let graph = SourceGraph(configuration: Configuration())
        let usr = "s:6Module9ConflictV"
        let first = makeDeclaration(usr: usr, path: "/Project/Second.swift", module: "Module")
        let second = makeDeclaration(usr: usr, path: "/Project/First.swift", module: "Module")
        graph.add(first)
        graph.add(second)
        graph.add(makeDeclaration(usr: "s:6Module8UniqueV", path: "/Project/A/Unique.swift", module: "Module"))

        XCTAssertEqual(graph.conflictingDeclarationsByUsr.keys.sorted(), [usr])
        XCTAssertTrue(graph.conflictingDeclarationsByUsr[usr]?.contains { $0 === first } ?? false)
        XCTAssertTrue(graph.conflictingDeclarationsByUsr[usr]?.contains { $0 === second } ?? false)

        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let pipeline = IndexPipeline(
            plan: IndexPlan(sourceFiles: [:]),
            graph: SourceGraphMutex(graph: graph),
            logger: logger.contextualized(with: "index"),
            configuration: Configuration(),
            swiftVersion: SwiftVersion(shell: ShellImpl(logger: logger))
        )

        XCTAssertThrowsError(try pipeline.perform()) { error in
            guard case let PeripheryError.declarationConflicts(conflicts) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(conflicts.count, 1)
            let conflict = conflicts[0]
            XCTAssertTrue(conflict.hasPrefix("USR '\(usr)':"), conflict)
            // Declarations are listed in location order, regardless of indexing order.
            guard let firstIndex = conflict.range(of: "First.swift")?.lowerBound,
                  let secondIndex = conflict.range(of: "Second.swift")?.lowerBound
            else { return XCTFail(conflict) }

            XCTAssertLessThan(firstIndex, secondIndex)
        }
    }

    func testDoesNotThrowWithoutConflicts() {
        let graph = SourceGraph(configuration: Configuration())
        graph.add(makeDeclaration(usr: "s:6Module1AV", path: "/Project/A.swift", module: "Module"))
        graph.add(makeDeclaration(usr: "s:6Module1BV", path: "/Project/B.swift", module: "Module"))
        XCTAssertTrue(graph.conflictingDeclarationsByUsr.isEmpty)
    }

    // MARK: - Private

    private func makeDeclaration(usr: String, path: String, module: String) -> Declaration {
        let file = SourceFile(path: FilePath(path), modules: [module])
        return Declaration(name: "Conflict", kind: .struct, usrs: [usr], location: Location(file: file, line: 1, column: 8))
    }
}
