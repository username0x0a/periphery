import Configuration
import Logger
import Shared
@testable import SourceGraph
import SystemPackage
import XCTest

final class SwiftUIStateMacroReferenceBuilderTest: XCTestCase {
    private let file = SourceFile(path: FilePath("/Project/View.swift"), modules: ["App"])

    func testIdentifiesStateMacroInAnotherModule() throws {
        let (graph, property, bodyGetter) = makeGraph(
            macroUsr: "s:11SwiftUICore5Stateyycfm",
            attributes: [DeclarationAttribute(name: "State", arguments: nil)]
        )

        try mutate(graph)

        XCTAssertTrue(graph.references(to: property).contains { $0.parent === bodyGetter })
    }

    func testDoesNotApplyToUnrelatedStateMacro() throws {
        let (graph, property, _) = makeGraph(
            macroUsr: "s:5Other5Stateyycfm",
            attributes: [DeclarationAttribute(name: "Other.State", arguments: nil)]
        )

        try mutate(graph)

        XCTAssertTrue(graph.references(to: property).isEmpty)
    }

    func testDoesNotApplyToStatePropertyWrapper() throws {
        let (graph, property, _) = makeGraph(
            macroUsr: nil,
            attributes: [DeclarationAttribute(name: "State", arguments: nil)]
        )

        try mutate(graph)

        XCTAssertTrue(graph.references(to: property).isEmpty)
    }

    // MARK: - Private

    /// Builds a view with a state property `count`, the macro-generated peers `_count` and `$count`, and a body that
    /// reads `$count`.
    private func makeGraph(
        macroUsr: String?,
        attributes: Set<DeclarationAttribute>
    ) -> (SourceGraph, Declaration, Declaration) {
        let graph = SourceGraph(configuration: Configuration())
        let view = Declaration(name: "View", kind: .struct, usrs: ["s:3App4ViewV"], location: location(1, 8))
        let property = Declaration(name: "count", kind: .varInstance, usrs: ["s:3App4ViewV5countSivp"], location: location(2, 24))
        property.attributes = attributes

        if let macroUsr {
            let macroReference = Reference(name: "State()", kind: .normal, declarationKind: .macro, usr: macroUsr, location: location(2, 6))
            macroReference.parent = property
            graph.add(macroReference, from: property)
        }

        makePeer(name: "_count", usr: "s:3App4ViewV6_countSivp", in: view, graph: graph)
        let projectedGetter = makePeer(name: "$count", usr: "s:3App4ViewV6$countSivp", in: view, graph: graph)

        let body = Declaration(name: "body", kind: .varInstance, usrs: ["s:3App4ViewV4bodyQrvp"], location: location(4, 9))
        let bodyGetter = Declaration(name: "getter:body", kind: .functionAccessorGetter, usrs: ["s:3App4ViewV4bodyQrvg"], location: location(4, 25))
        bodyGetter.parent = body
        body.declarations = [bodyGetter]

        let read = Reference(name: projectedGetter.name, kind: .normal, declarationKind: .functionAccessorGetter, usr: "s:3App4ViewV6$countSivpg", location: location(5, 20))
        read.parent = bodyGetter
        graph.add(read, from: bodyGetter)

        for decl in [property, body] {
            decl.parent = view
        }
        view.declarations.formUnion([property, body])
        graph.add([view, property, body, bodyGetter])

        return (graph, property, bodyGetter)
    }

    /// Adds an implicit peer property and its getter, returning the getter.
    @discardableResult
    private func makePeer(name: String, usr: String, in view: Declaration, graph: SourceGraph) -> Declaration {
        let peer = Declaration(name: name, kind: .varInstance, usrs: [usr], location: location(2, 5))
        peer.isImplicit = true
        peer.parent = view
        let getter = Declaration(name: "getter:\(name)", kind: .functionAccessorGetter, usrs: [usr + "g"], location: location(2, 5))
        getter.isImplicit = true
        getter.parent = peer
        peer.declarations = [getter]
        view.declarations.insert(peer)
        graph.add([peer, getter])
        return getter
    }

    private func location(_ line: Int, _ column: Int) -> Location {
        Location(file: file, line: line, column: column)
    }

    private func mutate(_ graph: SourceGraph) throws {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let swiftVersion = SwiftVersion(shell: ShellImpl(logger: logger))
        try SwiftUIStateMacroReferenceBuilder(graph: graph, configuration: Configuration(), swiftVersion: swiftVersion).mutate()
    }
}
