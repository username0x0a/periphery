import Foundation
import Logger
import Shared
import SystemPackage
@testable import TestShared
@testable import XcodeSupport
import XCTest

final class XcodeTargetTest: XCTestCase {
    private var project: XcodeProject!

    override func setUp() {
        super.setUp()
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let shell = ShellImpl(logger: logger)
        let xcodebuild = Xcodebuild(shell: shell, logger: logger)
        var loadedProjectPaths: Set<FilePath> = []
        project = try! XcodeProject(
            path: UIKitProjectPath,
            loadedProjectPaths: &loadedProjectPaths,
            xcodebuild: xcodebuild,
            shell: shell,
            logger: logger
        )
    }

    override func tearDown() {
        project = nil
        super.tearDown()
    }

    func testSourceFileInGroupWithoutFolder() throws {
        let target = project.targets.first { $0.name == "UIKitProject" }!
        try target.identifyFiles()

        XCTAssertTrue(target.files(kind: .interfaceBuilder).contains {
            $0.relativeTo(ProjectRootPath).string == "Tests/XcodeTests/UIKitProject/UIKitProject/FileInGroupWithoutFolder.xib"
        })
    }

    func testSourceFileInFileSystemSynchronizedFolder() throws {
        let target = try XCTUnwrap(project.targets.first { $0.name == "UIKitProject" })
        try target.identifyFiles()

        XCTAssertTrue(target.files(kind: .interfaceBuilder).contains {
            $0.relativeTo(ProjectRootPath).string == "Tests/XcodeTests/UIKitProject/UIKitProject/FileSystemFolder/XibViewController3.xib"
        })
    }

    func testFileSystemSynchronizedFolderWithGlobCharacters() throws {
        let tmpPath = FilePath(NSTemporaryDirectory()).appending("periphery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(atPath: tmpPath.string) }

        let folderPath = tmpPath.appending("**Folder")
        try FileManager.default.createDirectory(atPath: folderPath.appending("Nested").string, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: folderPath.appending("Nested/View.xib").string, contents: Data())

        let projectPath = tmpPath.appending("Project.xcodeproj")
        try FileManager.default.createDirectory(atPath: projectPath.string, withIntermediateDirectories: true)
        try fileSystemSynchronizedProject(folderName: "**Folder")
            .write(toFile: projectPath.appending("project.pbxproj").string, atomically: true, encoding: .utf8)

        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let shell = ShellImpl(logger: logger)
        var loadedProjectPaths: Set<FilePath> = []
        let project = try XcodeProject(
            path: projectPath,
            loadedProjectPaths: &loadedProjectPaths,
            xcodebuild: Xcodebuild(shell: shell, logger: logger),
            shell: shell,
            logger: logger
        )
        let target = try XCTUnwrap(project.targets.first)
        try target.identifyFiles()

        XCTAssertEqual(target.files(kind: .interfaceBuilder), [folderPath.appending("Nested/View.xib")])
    }

    func testIsTestTarget() {
        let projectTarget = project.targets.first { $0.name == "UIKitProject" }!
        let testTarget = project.targets.first { $0.name == "UIKitProjectTests" }!

        XCTAssertFalse(projectTarget.isTestTarget)
        XCTAssertTrue(testTarget.isTestTarget)
    }

    // MARK: - Private

    private func fileSystemSynchronizedProject(folderName: String) -> String {
        """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {
            };
            objectVersion = 77;
            objects = {
                AA0000000000000000000001 /* Project object */ = {
                    isa = PBXProject;
                    buildConfigurationList = AA0000000000000000000005;
                    compatibilityVersion = "Xcode 15.0";
                    mainGroup = AA0000000000000000000002;
                    projectDirPath = "";
                    projectRoot = "";
                    targets = (
                        AA0000000000000000000004,
                    );
                };
                AA0000000000000000000002 = {
                    isa = PBXGroup;
                    children = (
                        AA0000000000000000000003,
                    );
                    sourceTree = "<group>";
                };
                AA0000000000000000000003 = {
                    isa = PBXFileSystemSynchronizedRootGroup;
                    path = "\(folderName)";
                    sourceTree = "<group>";
                };
                AA0000000000000000000004 = {
                    isa = PBXNativeTarget;
                    buildConfigurationList = AA0000000000000000000005;
                    buildPhases = (
                    );
                    buildRules = (
                    );
                    dependencies = (
                    );
                    fileSystemSynchronizedGroups = (
                        AA0000000000000000000003,
                    );
                    name = Target;
                    productName = Target;
                    productType = "com.apple.product-type.application";
                };
                AA0000000000000000000005 = {
                    isa = XCConfigurationList;
                    buildConfigurations = (
                        AA0000000000000000000006,
                    );
                    defaultConfigurationName = Debug;
                };
                AA0000000000000000000006 = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                    };
                    name = Debug;
                };
            };
            rootObject = AA0000000000000000000001;
        }
        """
    }
}
