import SystemPackage
@testable import TestShared
import XCTest

#if os(macOS)
    final class ObjcAccessibleRetentionTest: FixtureSourceGraphTestCase {
        func testRetainsOptionalProtocolMethodImplementedInSubclass() throws {
            try XCTSkipIf(Self.swiftVersion.version.isVersion(lessThan: "6.3"), "Requires Swift >= 6.3")
            analyze(retainPublic: true) {
                assertReferenced(.class("FixtureClass125Base"))
                assertReferenced(.class("FixtureClass125")) {
                    self.assertReferenced(.functionMethodInstance("fileManager(_:shouldRemoveItemAtPath:)"))
                }
            }
        }

        func testDeclarationsSharingObjcNameAreDeterministic() {
            // Only the first of the declarations sharing a USR in the same file is indexed.
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureSharedObjcNameFirst1"))
                assertNotIndexed(.class("FixtureSharedObjcNameSecond1"))
                assertReferenced(.protocol("FixtureSharedObjcNameProtocol1")) {
                    self.assertReferenced(.functionMethodInstance("fetch1(completionHandler:)"))
                    self.assertNotIndexed(.functionMethodInstance("fetch1()"))
                }
                assertReferenced(.class("FixtureSharedObjcNameFirst2"))
                assertNotIndexed(.class("FixtureSharedObjcNameSecond2"))
                assertReferenced(.protocol("FixtureSharedObjcNameProtocol2")) {
                    self.assertReferenced(.functionMethodInstance("fetch2(completionHandler:)"))
                    self.assertNotIndexed(.functionMethodInstance("fetch2()"))
                }
                assertReferenced(.class("FixtureSharedObjcNameFirst3"))
                assertNotIndexed(.class("FixtureSharedObjcNameSecond3"))
                assertReferenced(.protocol("FixtureSharedObjcNameProtocol3")) {
                    self.assertReferenced(.functionMethodInstance("fetch3(completionHandler:)"))
                    self.assertNotIndexed(.functionMethodInstance("fetch3()"))
                }
                assertReferenced(.class("FixtureSharedObjcNameFirst4"))
                assertNotIndexed(.class("FixtureSharedObjcNameSecond4"))
                assertReferenced(.protocol("FixtureSharedObjcNameProtocol4")) {
                    self.assertReferenced(.functionMethodInstance("fetch4(completionHandler:)"))
                    self.assertNotIndexed(.functionMethodInstance("fetch4()"))
                }
                assertReferenced(.class("FixtureSharedObjcNameFirst5"))
                assertNotIndexed(.class("FixtureSharedObjcNameSecond5"))
                assertReferenced(.protocol("FixtureSharedObjcNameProtocol5")) {
                    self.assertReferenced(.functionMethodInstance("fetch5(completionHandler:)"))
                    self.assertNotIndexed(.functionMethodInstance("fetch5()"))
                }
                assertReferenced(.class("FixtureSharedObjcNameFirst6"))
                assertNotIndexed(.class("FixtureSharedObjcNameSecond6"))
                assertReferenced(.protocol("FixtureSharedObjcNameProtocol6")) {
                    self.assertReferenced(.functionMethodInstance("fetch6(completionHandler:)"))
                    self.assertNotIndexed(.functionMethodInstance("fetch6()"))
                }
            }
        }

        func testRetainsOptionalProtocolMethod() {
            analyze(retainPublic: true) {
                assertReferenced(.class("FixtureClass127")) {
                    self.assertReferenced(.functionMethodInstance("someFunc()"))
                }
                assertReferenced(.protocol("FixtureProtocol127")) {
                    self.assertReferenced(.functionMethodInstance("optionalFunc()"))
                }
            }
        }

        func testRetainsObjcAnnotatedClass() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass21"))
            }
        }

        func testRetainsImplicitlyObjcAccessibleClass() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass126"))
            }
        }

        func testRetainsObjcAnnotatedMembers() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass22")) {
                    self.assertReferenced(.varInstance("someVar"))
                    self.assertReferenced(.functionMethodInstance("someMethod()"))
                    self.assertReferenced(.functionMethodInstance("somePrivateMethod()"))
                }
            }
        }

        func testDoesNotRetainObjcAnnotatedWithoutOption() {
            analyze {
                assertNotReferenced(.class("FixtureClass23"))
            }
        }

        func testDoesNotRetainMembersOfObjcAnnotatedClass() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass24")) {
                    self.assertNotReferenced(.functionMethodInstance("someMethod()"))
                    self.assertNotReferenced(.varInstance("someVar"))
                }
            }
        }

        func testObjcMembersAnnotationRetainsMembers() {
            analyze(retainObjcAccessible: true) {
                assertReferenced(.class("FixtureClass25")) {
                    self.assertReferenced(.varInstance("someVar"))
                    self.assertReferenced(.functionMethodInstance("someMethod()"))
                    self.assertNotReferenced(.functionMethodInstance("somePrivateMethod()"))
                }
            }
        }
    }
#endif
