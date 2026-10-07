import Configuration
import Foundation
import Shared

/// Moves references to types used in the generic requirements of a constrained extension to the members of the
/// extension, e.g. `SomeProtocol` in `extension Array where Element: SomeProtocol {}`.
///
/// Extensions of external types are retained, and extensions of internal types are folded into the extended type,
/// either of which would cause the requirement types to be retained even when no member of the extension is used.
/// Extensions that add a protocol conformance are excluded, as the requirements are part of the conformance.
///
/// Must run before ExtensionReferenceBuilder, which folds and retains extensions.
final class ConstrainedExtensionReferenceBuilder: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        let extensionDecls = graph.declarations(ofKinds: [.extensionClass, .extensionStruct, .extensionEnum])

        for extensionDecl in extensionDecls {
            guard !extensionDecl.related.contains(where: { $0.role == .conformedType }) else { continue }

            let requirementReferences = extensionDecl.references.filter { $0.role == .genericRequirementType }

            for requirementReference in requirementReferences {
                graph.remove(requirementReference)

                for memberDecl in extensionDecl.declarations {
                    let reference = Reference(
                        name: requirementReference.name,
                        kind: requirementReference.kind,
                        declarationKind: requirementReference.declarationKind,
                        usr: requirementReference.usr,
                        location: requirementReference.location
                    )
                    reference.role = requirementReference.role
                    reference.parent = memberDecl
                    graph.add(reference, from: memberDecl)
                }
            }
        }
    }
}
