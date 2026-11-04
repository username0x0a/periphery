import Foundation
@testable import Logger
import XCTest

final class LoggerStreamsTest: XCTestCase {
    func testMessagesGoToStdoutByDefault() {
        let logger = Logger(quiet: false, verbose: true, colorMode: .never)
        XCTAssertEqual(logger.messagesOutput, stdout)
    }

    func testMessagesGoToStderrForMachineReadableOutput() {
        let logger = Logger(quiet: false, verbose: true, colorMode: .never, messagesToStderr: true)
        XCTAssertEqual(logger.messagesOutput, stderr)
    }
}
