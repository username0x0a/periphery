import Foundation
import Logger
import PathKit
import Shared
import SourceGraph
import SystemPackage
@testable import TestShared
import XcodeProj
@testable import XcodeSupport
import XCTest

final class XcodeProjectFormatTest: XCTestCase {
    private var tmpPath: FilePath!

    override func setUp() {
        super.setUp()
        tmpPath = FilePath(NSTemporaryDirectory()).appending("periphery-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tmpPath.string)
        tmpPath = nil
        super.tearDown()
    }

    func testJSONProjectFormat() throws {
        // Convert a copy of the UIKit project to the JSON project format introduced in Xcode 27.2.
        let projectDirectory = UIKitProjectPath.removingLastComponent()
        try FileManager.default.copyItem(atPath: projectDirectory.string, toPath: tmpPath.string)
        let jsonProjectPath = try tmpPath.appending(XCTUnwrap(UIKitProjectPath.lastComponent).string)
        try XcodeProj(pathString: jsonProjectPath.string).write(path: Path(jsonProjectPath.string), format: .xcproj)
        try FileManager.default.removeItem(atPath: jsonProjectPath.appending("project.pbxproj").string)
        XCTAssertTrue(jsonProjectPath.appending("project.xcproj").exists)

        let propertyListProject = try loadProject(at: UIKitProjectPath)
        let jsonProject = try loadProject(at: jsonProjectPath)

        XCTAssertEqual(jsonProject.targets.map(\.name).sorted(), propertyListProject.targets.map(\.name).sorted())

        let appTarget = try XCTUnwrap(jsonProject.targets.first { $0.name == "UIKitProject" })
        try appTarget.identifyFiles()
        XCTAssertFalse(appTarget.files(kind: .interfaceBuilder).isEmpty)
        XCTAssertFalse(appTarget.files(kind: .xcDataModel).isEmpty)
        XCTAssertFalse(appTarget.files(kind: .infoPlist).isEmpty)

        for propertyListTarget in propertyListProject.targets {
            let jsonTarget = try XCTUnwrap(jsonProject.targets.first { $0.name == propertyListTarget.name })
            try propertyListTarget.identifyFiles()
            try jsonTarget.identifyFiles()

            for kind in ProjectFileKind.allCases {
                XCTAssertEqual(
                    jsonTarget.files(kind: kind).mapSet { $0.relativeTo(tmpPath).string },
                    propertyListTarget.files(kind: kind).mapSet { $0.relativeTo(projectDirectory).string },
                    "\(propertyListTarget.name) \(kind)"
                )
            }
        }
    }

    // MARK: - Private

    private func loadProject(at path: FilePath) throws -> XcodeProject {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let shell = ShellImpl(logger: logger)
        var loadedProjectPaths: Set<FilePath> = []
        return try XcodeProject(
            path: path,
            loadedProjectPaths: &loadedProjectPaths,
            xcodebuild: Xcodebuild(shell: shell, logger: logger),
            shell: shell,
            logger: logger
        )
    }
}
