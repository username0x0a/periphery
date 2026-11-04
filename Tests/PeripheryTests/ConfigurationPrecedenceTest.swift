import Configuration
import Foundation
import SystemPackage
import XCTest

final class ConfigurationPrecedenceTest: XCTestCase {
    private var configurationPath: FilePath!

    override func setUp() {
        super.setUp()
        configurationPath = FilePath(NSTemporaryDirectory()).appending("periphery-\(UUID().uuidString).yml")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: configurationPath.string)
        configurationPath = nil
        super.tearDown()
    }

    func testCommandLineValueEqualToDefaultOverridesFile() throws {
        let configuration = try loadConfiguration("format: json\nretain_public: true\n")

        configuration.apply(\.$outputFormat, .xcode)
        configuration.apply(\.$retainPublic, false)

        XCTAssertEqual(configuration.outputFormat, .xcode)
        XCTAssertFalse(configuration.retainPublic)
    }

    func testValueNotGivenOnCommandLineKeepsFileValue() throws {
        let configuration = try loadConfiguration("format: json\nretain_public: true\nproject: Some.xcodeproj\n")

        configuration.apply(\.$outputFormat, nil)
        configuration.apply(\.$retainPublic, nil)
        configuration.apply(\.$project, nil)

        XCTAssertEqual(configuration.outputFormat, .json)
        XCTAssertTrue(configuration.retainPublic)
        XCTAssertEqual(configuration.project, FilePath("Some.xcodeproj"))
    }

    // MARK: - Private

    private func loadConfiguration(_ contents: String) throws -> Configuration {
        try contents.write(toFile: configurationPath.string, atomically: true, encoding: .utf8)
        let configuration = Configuration()
        try configuration.load(from: configurationPath)
        return configuration
    }
}
