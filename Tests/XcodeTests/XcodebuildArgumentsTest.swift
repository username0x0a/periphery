import Foundation
import Logger
import Shared
import Synchronization
import SystemPackage
@testable import XcodeSupport
import XCTest

final class XcodebuildArgumentsTest: XCTestCase {
    func testBuildPassesSchemeProjectAndBuildArgumentsAsLiteralArguments() throws {
        let shell = RecordingShell()
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)
        let xcodebuild = Xcodebuild(shell: shell, logger: logger)
        var loadedProjectPaths: Set<FilePath> = []
        let project = try XcodeProject(
            path: UIKitProjectPath,
            loadedProjectPaths: &loadedProjectPaths,
            xcodebuild: xcodebuild,
            shell: shell,
            logger: logger
        )

        try xcodebuild.build(
            project: project,
            scheme: "Scheme With $(Spaces)",
            allSchemes: ["Scheme With $(Spaces)"],
            additionalArguments: ["-skipMacroValidation", "OTHER_SWIFT_FLAGS=$(inherited) -no-warnings-as-errors"]
        )

        let command = try XCTUnwrap(shell.commands.last { $0.first == "xcodebuild" && $0.contains("build-for-testing") })
        XCTAssertTrue(command.contains(UIKitProjectPath.lexicallyNormalized().string))
        XCTAssertTrue(command.contains("Scheme With $(Spaces)"))
        XCTAssertEqual(Array(command.suffix(2)), ["-skipMacroValidation", "OTHER_SWIFT_FLAGS=$(inherited) -no-warnings-as-errors"])
        XCTAssertFalse(command.contains { $0.hasPrefix("\"") || $0.hasPrefix("'") }, "\(command)")
    }
}

private final class RecordingShell: Shell {
    private let recordedCommands = Mutex<[[String]]>([])

    var commands: [[String]] {
        recordedCommands.withLock { $0 }
    }

    func exec(_ args: [String]) throws -> String {
        recordedCommands.withLock { $0.append(args) }
        return args.contains("-version") ? "Xcode 27.0" : ""
    }

    func execStatus(_ args: [String]) throws -> Int32 {
        recordedCommands.withLock { $0.append(args) }
        return 0
    }
}
