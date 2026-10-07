import Foundation

@resultBuilder
public enum PublicResultBuilderUsedByPublicFunctionParameter {
    public static func buildBlock(_ components: String...) -> String {
        components.joined()
    }
}

@resultBuilder
public enum PublicResultBuilderUsedByPublicInitializerParameter {
    public static func buildBlock(_ components: String...) -> String {
        components.joined()
    }
}

public struct PublicResultBuilderUsedByPublicParameterRetainer {
    public init(@PublicResultBuilderUsedByPublicInitializerParameter content: () -> String) {
        _ = content()
    }

    public func retain(@PublicResultBuilderUsedByPublicFunctionParameter content: () -> String) {
        _ = content()
    }
}
