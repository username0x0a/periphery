#if canImport(SwiftUI)
    import SwiftUI

    func fixtureStateInitialValue1() -> Int { 0 }
    func fixtureStateInitialValue2() -> Int { 0 }

    public struct FixtureSwiftUIStateView: View {
        @State private var readState = fixtureStateInitialValue1()
        @State private var projectedValueReadState = 0
        @State private var backingStorageReadState = 0
        @State private var backingStorageAssignedState: Int
        @State private var unusedState = fixtureStateInitialValue2()

        public init() {
            _backingStorageAssignedState = State(initialValue: 0)
        }

        public var body: some View {
            VStack {
                Text("\(readState)")
                Stepper("", value: $projectedValueReadState)
                Text("\(_backingStorageReadState.wrappedValue)")
            }
        }
    }
#endif
