protocol ConstrainedExtensionProtocol0 {}
struct ConstrainedExtensionStruct0 {}
protocol ConstrainedExtensionProtocol1 {}
protocol ConstrainedExtensionProtocol2 {}
protocol ConstrainedExtensionProtocol3 {}

public struct ConstrainedExtensionStruct1<T> {
    public init() {}
}

// Unused constrained extensions of external and internal types.
extension Array where Element: ConstrainedExtensionProtocol0 {
    func unusedFunc() {}
}

extension ConstrainedExtensionStruct1 where T == ConstrainedExtensionStruct0 {
    func unusedFunc() {}
}

// Used constrained extension.
extension Dictionary where Value: ConstrainedExtensionProtocol1 {
    func usedFunc() {}
}

struct ConstrainedExtensionStruct2: ConstrainedExtensionProtocol1 {}

// Constrained extension adding a conformance.
extension ConstrainedExtensionStruct1: ConstrainedExtensionProtocol3 where T: ConstrainedExtensionProtocol2 {}

public class ConstrainedExtensionRetainer {
    public func retain() {
        [1: ConstrainedExtensionStruct2()].usedFunc()
    }
}
