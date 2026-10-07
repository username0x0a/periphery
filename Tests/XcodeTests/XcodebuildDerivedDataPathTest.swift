import Foundation
import Logger
import SystemPackage
@testable import XcodeSupport
import XCTest

final class XcodebuildDerivedDataPathTest: XCTestCase {
    private var xcodebuild: Xcodebuild!
    private var project: XcodeProject!

    override func setUp() {
        super.setUp()

        let shell = ShellMock(output: "Xcode 27.0")
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        var loadedProjectPaths: Set<FilePath> = []
        xcodebuild = Xcodebuild(shell: shell, logger: logger)
        project = try! XcodeProject(path: UIKitProjectPath, loadedProjectPaths: &loadedProjectPaths, xcodebuild: xcodebuild, shell: shell, logger: logger)
    }

    override func tearDown() {
        xcodebuild = nil
        project = nil
        super.tearDown()
    }

    func testPathIsIndependentOfSchemeOrder() throws {
        let pathA = try xcodebuild.derivedDataPath(for: project, schemes: ["SchemeA", "SchemeB", "SchemeC"])
        let pathB = try xcodebuild.derivedDataPath(for: project, schemes: ["SchemeC", "SchemeA", "SchemeB"])
        XCTAssertEqual(pathA, pathB)
    }

    func testPathDiffersForDistinctSchemes() throws {
        let pathA = try xcodebuild.derivedDataPath(for: project, schemes: ["AB", "C"])
        let pathB = try xcodebuild.derivedDataPath(for: project, schemes: ["A", "BC"])
        XCTAssertNotEqual(pathA, pathB)
    }
}
