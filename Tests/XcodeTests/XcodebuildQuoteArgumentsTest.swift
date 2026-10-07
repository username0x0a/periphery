import Foundation
import Logger
@testable import XcodeSupport
import XCTest

final class XcodebuildQuoteArgumentsTest: XCTestCase {
    private var xcodebuild: Xcodebuild!

    override func setUp() {
        super.setUp()

        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        xcodebuild = Xcodebuild(shell: ShellMock(output: ""), logger: logger)
    }

    override func tearDown() {
        xcodebuild = nil
        super.tearDown()
    }

    func testQuotesFlagValue() {
        XCTAssertEqual(
            xcodebuild.quote(arguments: ["-destination", "generic/platform=iOS"]),
            ["-destination", "\"generic/platform=iOS\""]
        )
    }

    func testDoesNotRequoteQuotedFlagValue() {
        XCTAssertEqual(
            xcodebuild.quote(arguments: ["-destination", "'generic/platform=iOS'"]),
            ["-destination", "'generic/platform=iOS'"]
        )
    }

    func testDoesNotRequoteHandQuotedBuildSettingFollowingBooleanFlag() {
        XCTAssertEqual(
            xcodebuild.quote(arguments: ["-skipMacroValidation", "OTHER_SWIFT_FLAGS='$(inherited) -no-warnings-as-errors'"]),
            ["-skipMacroValidation", "OTHER_SWIFT_FLAGS='$(inherited) -no-warnings-as-errors'"]
        )
        XCTAssertEqual(
            xcodebuild.quote(arguments: ["-skipMacroValidation", "OTHER_SWIFT_FLAGS=\"$(inherited) -no-warnings-as-errors\""]),
            ["-skipMacroValidation", "OTHER_SWIFT_FLAGS=\"$(inherited) -no-warnings-as-errors\""]
        )
    }
}
