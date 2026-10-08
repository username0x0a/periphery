import Configuration
import Foundation
import Logger
@testable import ProjectDrivers
import Shared
import Synchronization
import XCTest

final class XcodeProjectDriverSchemesTest: XCTestCase {
    func testDoesNotValidateSchemes() throws {
        let shell = RecordingShell()
        let configuration = Configuration()
        configuration.schemes = ["SchemeThatDoesNotExist"]
        configuration.outputFormat = .json
        let logger = Logger(quiet: true, verbose: false, colorMode: .never)

        XCTAssertNoThrow(try XcodeProjectDriver(
            projectPath: UIKitProjectPath,
            configuration: configuration,
            shell: shell,
            logger: logger
        ))
        XCTAssertFalse(shell.commands.contains { $0.contains("-list") }, "\(shell.commands)")
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
