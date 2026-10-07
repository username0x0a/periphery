import Foundation

// Declarations sharing an Objective-C name have the same USR.

@objc(FixtureSharedObjcName1) class FixtureSharedObjcNameFirst1: NSObject {}
@objc(FixtureSharedObjcName1) class FixtureSharedObjcNameSecond1: NSObject {}

@objc protocol FixtureSharedObjcNameProtocol1 {
    func fetch1(completionHandler: @escaping (Int) -> Void)
    func fetch1() async -> Int
}

@objc(FixtureSharedObjcName2) class FixtureSharedObjcNameFirst2: NSObject {}
@objc(FixtureSharedObjcName2) class FixtureSharedObjcNameSecond2: NSObject {}

@objc protocol FixtureSharedObjcNameProtocol2 {
    func fetch2(completionHandler: @escaping (Int) -> Void)
    func fetch2() async -> Int
}

@objc(FixtureSharedObjcName3) class FixtureSharedObjcNameFirst3: NSObject {}
@objc(FixtureSharedObjcName3) class FixtureSharedObjcNameSecond3: NSObject {}

@objc protocol FixtureSharedObjcNameProtocol3 {
    func fetch3(completionHandler: @escaping (Int) -> Void)
    func fetch3() async -> Int
}

@objc(FixtureSharedObjcName4) class FixtureSharedObjcNameFirst4: NSObject {}
@objc(FixtureSharedObjcName4) class FixtureSharedObjcNameSecond4: NSObject {}

@objc protocol FixtureSharedObjcNameProtocol4 {
    func fetch4(completionHandler: @escaping (Int) -> Void)
    func fetch4() async -> Int
}

@objc(FixtureSharedObjcName5) class FixtureSharedObjcNameFirst5: NSObject {}
@objc(FixtureSharedObjcName5) class FixtureSharedObjcNameSecond5: NSObject {}

@objc protocol FixtureSharedObjcNameProtocol5 {
    func fetch5(completionHandler: @escaping (Int) -> Void)
    func fetch5() async -> Int
}

@objc(FixtureSharedObjcName6) class FixtureSharedObjcNameFirst6: NSObject {}
@objc(FixtureSharedObjcName6) class FixtureSharedObjcNameSecond6: NSObject {}

@objc protocol FixtureSharedObjcNameProtocol6 {
    func fetch6(completionHandler: @escaping (Int) -> Void)
    func fetch6() async -> Int
}
