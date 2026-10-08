import Configuration
import Foundation
import Logger
@testable import PeripheryKit
@testable import SourceGraph
import SystemPackage
import XCTest

final class OutputFormatterDeterminismTest: XCTestCase {
    private var configuration: Configuration!
    private var logger: Logger!
    private var results: [ScanResult]!

    override func setUp() {
        super.setUp()

        configuration = Configuration()
        configuration.relativeResults = true
        logger = Logger(quiet: true, verbose: false, colorMode: .never)

        let file = SourceFile(path: FilePath("Sources/Module/File.swift"), modules: ["Module"])
        let declaration = Declaration(
            name: "SomeClass",
            kind: .class,
            usrs: ["usr-b", "usr-a"],
            location: Location(file: file, line: 1, column: 1)
        )
        declaration.attributes = [
            DeclarationAttribute(name: "available", arguments: "macOS 15"),
            DeclarationAttribute(name: "available", arguments: "iOS 18"),
            DeclarationAttribute(name: "MainActor", arguments: nil),
            DeclarationAttribute(name: "available", arguments: "watchOS 11"),
        ]
        results = [ScanResult(declaration: declaration, annotation: .unused)]
    }

    override func tearDown() {
        configuration = nil
        logger = nil
        results = nil
        super.tearDown()
    }

    func testJsonOutputIsSorted() throws {
        let output = try XCTUnwrap(JsonFormatter(configuration: configuration, logger: logger).format(results, colored: false))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]]).first

        XCTAssertEqual(
            object?["attributes"] as? [String],
            ["MainActor", "available(iOS 18)", "available(macOS 15)", "available(watchOS 11)"]
        )
        assertKeysSorted(in: output)
    }

    func testCodeClimateOutputIsSorted() throws {
        let output = try XCTUnwrap(CodeClimateFormatter(configuration: configuration, logger: logger).format(results, colored: false))
        assertKeysSorted(in: output)
    }

    func testGitLabCodeQualityOutputIsSorted() throws {
        let output = try XCTUnwrap(GitLabCodeQualityFormatter(configuration: configuration, logger: logger).format(results, colored: false))
        assertKeysSorted(in: output)
    }

    func testNameOverride() throws {
        let declaration = try XCTUnwrap(results.first).declaration
        declaration.commentCommands = [.override([.name("OverriddenName")])]

        let xcodeOutput = try XCTUnwrap(XcodeFormatter(configuration: configuration, logger: logger).format(results, colored: false))
        XCTAssertTrue(xcodeOutput.contains("Unused class 'OverriddenName'"), xcodeOutput)

        let jsonOutput = try XCTUnwrap(JsonFormatter(configuration: configuration, logger: logger).format(results, colored: false))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(jsonOutput.utf8)) as? [[String: Any]]).first
        XCTAssertEqual(object?["name"] as? String, "OverriddenName")
    }

    // MARK: - Private

    private func assertKeysSorted(in output: String, file: StaticString = #filePath, line: UInt = #line) {
        // Keys of each object are printed on their own line at the same indentation level.
        var keysByIndentation: [Int: [String]] = [:]

        for outputLine in output.split(separator: "\n") {
            let indentation = outputLine.prefix(while: { $0 == " " }).count
            let trimmed = outputLine.dropFirst(indentation)

            if trimmed.hasPrefix("}") {
                if let keys = keysByIndentation.removeValue(forKey: indentation + 2) {
                    XCTAssertEqual(keys, keys.sorted(), file: file, line: line)
                }
            } else if trimmed.hasPrefix("\""), let keyEnd = trimmed.dropFirst().firstIndex(of: "\""),
                      trimmed[trimmed.index(after: keyEnd)...].hasPrefix(" :")
            {
                keysByIndentation[indentation, default: []].append(String(trimmed[trimmed.index(after: trimmed.startIndex) ..< keyEnd]))
            }
        }
    }
}
