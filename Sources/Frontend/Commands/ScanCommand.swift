import ArgumentParser
import Configuration
import Foundation
import Logger
import PeripheryKit
import Shared
import SystemPackage

struct ScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan for unused code"
    )

    @Argument(help: "Arguments following '--' will be passed to the underlying build tool, which is either 'swift build' or 'xcodebuild' depending on your project")
    var buildArguments: [String] = []

    @Flag(help: "Enable guided setup")
    var setup: Bool = defaultConfiguration.guidedSetup

    @Option(help: "Path to the root directory of your project")
    var projectRoot: FilePath = projectRootDefault

    @Option(help: "Path to configuration file. By default Periphery will look for .periphery.yml in the current directory")
    var config: FilePath?

    @Option(help: "Path to your project's .xcodeproj or .xcworkspace")
    var project: FilePath?

    @Option(parsing: .upToNextOption, help: "Schemes to build. All targets built by these schemes will be scanned")
    var schemes: [String] = []

    @Option(help: "Output format (default: \(defaultConfiguration.$outputFormat.defaultValue.rawValue))")
    var format: OutputFormat?

    @Flag(inversion: .prefixedNo, help: "Exclude test targets from indexing")
    var excludeTests: Bool?

    @Option(parsing: .upToNextOption, help: "Targets to exclude from indexing")
    var excludeTargets: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from indexing")
    var indexExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to exclude from the results. Note that this option is purely cosmetic, these files will still be indexed")
    var reportExclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs to include in the results. This option supersedes '--report-exclude'. Note that this option is purely cosmetic, these files will still be indexed")
    var reportInclude: [String] = []

    @Option(parsing: .upToNextOption, help: "Source file globs for which all containing declarations will be retained")
    var retainFiles: [String] = []

    @Option(parsing: .upToNextOption, help: "Index store paths. Implies '--skip-build'")
    var indexStorePath: [FilePath] = []

    @Flag(inversion: .prefixedNo, help: "Retain all public declarations, recommended for framework/library projects")
    var retainPublic: Bool?

    @Option(parsing: .upToNextOption, help: "Public SPIs (System Programming Interfaces) to check for unused code even when '--retain-public' is enabled")
    var noRetainSPI: [String] = []

    @Flag(inversion: .prefixedNo, help: "Disable identification of redundant public accessibility")
    var disableRedundantPublicAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Disable identification of unused imports")
    var disableUnusedImportAnalysis: Bool?

    @Flag(inversion: .prefixedNo, help: "Report superfluous ignore comments")
    var superfluousIgnoreComments: Bool?

    @Option(parsing: .upToNextOption, help: "Names of unused imported modules to retain")
    var retainUnusedImportedModules: [String] = []

    @Flag(inversion: .prefixedNo, help: "Retain properties that are assigned, but never used")
    var retainAssignOnlyProperties: Bool?

    @Option(parsing: .upToNextOption, help: "Property types to retain if the property is assigned, but never read")
    var retainAssignOnlyPropertyTypes: [String] = []

    @Option(parsing: .upToNextOption, help: "Names of external protocols that inherit Encodable. Properties and CodingKey enums of types conforming to these protocols will be retained")
    var externalEncodableProtocols: [String] = []

    @Option(parsing: .upToNextOption, help: "Names of external protocols that inherit Codable. Properties and CodingKey enums of types conforming to these protocols will be retained")
    var externalCodableProtocols: [String] = []

    @Option(parsing: .upToNextOption, help: "Names of XCTestCase subclasses that reside in external targets")
    var externalTestCaseClasses: [String] = []

    @Flag(inversion: .prefixedNo, help: "Retain declarations that are exposed to Objective-C implicitly by inheriting NSObject classes, or explicitly with the @objc and @objcMembers attributes")
    var retainObjcAccessible: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain declarations that are exposed to Objective-C explicitly with the @objc and @objcMembers attributes")
    var retainObjcAnnotated: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain unused protocol function parameters, even if the parameter is unused in all conforming functions")
    var retainUnusedProtocolFuncParams: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain SwiftUI previews")
    var retainSwiftUIPreviews: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Codable types (including Encodable and Decodable)")
    var retainCodableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Encodable types only")
    var retainEncodableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Equatable types, including Hashable types")
    var retainEquatableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Retain properties on Hashable types")
    var retainHashableProperties: Bool?

    @Flag(inversion: .prefixedNo, help: "Clean existing build artifacts before building")
    var cleanBuild: Bool?

    @Flag(inversion: .prefixedNo, help: "Skip the project build step")
    var skipBuild: Bool?

    @Flag(inversion: .prefixedNo, help: "Output result paths relative to the current directory")
    var relativeResults: Bool?

    @Flag(inversion: .prefixedNo, help: "Exit with non-zero status if any unused code is found")
    var strict: Bool?

    @Flag(inversion: .prefixedNo, help: "Disable checking for updates")
    var disableUpdateCheck: Bool?

    @Flag(inversion: .prefixedNo, help: "Enable verbose logging")
    var verbose: Bool?

    @Flag(inversion: .prefixedNo, help: "Only output results")
    var quiet: Bool?

    @Option(help: "Colored output mode (default: \(defaultConfiguration.$color.defaultValue.rawValue))")
    var color: ColorOption?

    @Flag(name: .customLong("no-color"), help: .hidden)
    var noColor: Bool = false

    @Option(help: "JSON package manifest path (obtained using `swift package describe --type json` or manually)")
    var jsonPackageManifestPath: FilePath?

    @Option(help: "Baseline file path used to filter results")
    var baseline: FilePath?

    @Option(help: "Baseline file path where results are written. Pass the same path to '--baseline' in subsequent scans to exclude the results recorded in the baseline.")
    var writeBaseline: FilePath?

    @Option(help: "File path where formatted results are written.")
    var writeResults: FilePath?

    @Option(help: "Project configuration for non-Apple build systems")
    var genericProjectConfig: FilePath?

    @Flag(inversion: .prefixedNo, help: "Enable Bazel project mode")
    var bazel: Bool?

    @Option(help: "Filter pattern applied to the Bazel top-level targets query")
    var bazelFilter: String?

    @Option(help: "Query expression used for the Bazel top-level targets query. Overrides the default query and bypasses bazelFilter.")
    var bazelQuery: String?

    @Option(help: "Path to a global index store populated by Bazel. If provided, will be used instead of individual module stores.")
    var bazelIndexStore: FilePath?

    @Flag(inversion: .prefixedNo, help: "Enable Bazel visibility checking")
    var bazelCheckVisibility: Bool?

    private static let defaultConfiguration = Configuration()

    func run() throws {
        if !FileManager.default.changeCurrentDirectoryPath(projectRoot.string) {
            throw PeripheryError.changeCurrentDirectoryFailed(projectRoot)
        }

        let configuration = Configuration()

        if !setup {
            try configuration.load(from: config)
        }

        configuration.guidedSetup = setup
        configuration.projectRoot = projectRoot
        configuration.apply(\.$project, project)
        configuration.apply(\.$schemes, schemes.nonEmpty)
        configuration.apply(\.$indexExclude, indexExclude.nonEmpty)
        configuration.apply(\.$reportExclude, reportExclude.nonEmpty)
        configuration.apply(\.$reportInclude, reportInclude.nonEmpty)
        configuration.apply(\.$outputFormat, format)
        configuration.apply(\.$retainFiles, retainFiles.nonEmpty)
        configuration.apply(\.$retainPublic, retainPublic)
        configuration.apply(\.$noRetainSPI, noRetainSPI.nonEmpty)
        configuration.apply(\.$retainAssignOnlyProperties, retainAssignOnlyProperties)
        configuration.apply(\.$retainAssignOnlyPropertyTypes, retainAssignOnlyPropertyTypes.nonEmpty)
        configuration.apply(\.$retainObjcAccessible, retainObjcAccessible)
        configuration.apply(\.$retainObjcAnnotated, retainObjcAnnotated)
        configuration.apply(\.$retainUnusedProtocolFuncParams, retainUnusedProtocolFuncParams)
        configuration.apply(\.$retainSwiftUIPreviews, retainSwiftUIPreviews)
        configuration.apply(\.$disableRedundantPublicAnalysis, disableRedundantPublicAnalysis)
        configuration.apply(\.$disableUnusedImportAnalysis, disableUnusedImportAnalysis)
        configuration.apply(\.$superfluousIgnoreComments, superfluousIgnoreComments)
        configuration.apply(\.$retainUnusedImportedModules, retainUnusedImportedModules.nonEmpty)
        configuration.apply(\.$externalEncodableProtocols, externalEncodableProtocols.nonEmpty)
        configuration.apply(\.$externalCodableProtocols, externalCodableProtocols.nonEmpty)
        configuration.apply(\.$externalTestCaseClasses, externalTestCaseClasses.nonEmpty)
        configuration.apply(\.$verbose, verbose)
        configuration.apply(\.$quiet, quiet)
        configuration.apply(\.$color, noColor ? .never : color)
        configuration.apply(\.$disableUpdateCheck, disableUpdateCheck)
        configuration.apply(\.$strict, strict)
        configuration.apply(\.$indexStorePath, indexStorePath.nonEmpty)
        configuration.apply(\.$skipBuild, skipBuild)
        configuration.apply(\.$excludeTests, excludeTests)
        configuration.apply(\.$excludeTargets, excludeTargets.nonEmpty)
        configuration.apply(\.$cleanBuild, cleanBuild)
        configuration.apply(\.$buildArguments, buildArguments.nonEmpty)
        configuration.apply(\.$relativeResults, relativeResults)
        configuration.apply(\.$retainCodableProperties, retainCodableProperties)
        configuration.apply(\.$retainEncodableProperties, retainEncodableProperties)
        configuration.apply(\.$retainEquatableProperties, retainEquatableProperties)
        configuration.apply(\.$retainHashableProperties, retainHashableProperties)
        configuration.apply(\.$jsonPackageManifestPath, jsonPackageManifestPath)
        configuration.apply(\.$baseline, baseline)
        configuration.apply(\.$writeBaseline, writeBaseline)
        configuration.apply(\.$writeResults, writeResults)
        configuration.apply(\.$genericProjectConfig, genericProjectConfig)
        configuration.apply(\.$bazel, bazel)
        configuration.apply(\.$bazelFilter, bazelFilter)
        configuration.apply(\.$bazelQuery, bazelQuery)
        configuration.apply(\.$bazelIndexStore, bazelIndexStore)
        configuration.apply(\.$bazelCheckVisibility, bazelCheckVisibility)

        configuration.buildFilenameMatchers()

        let logger = Logger(configuration: configuration)
        ScanPreflight.applyOutputFormatRequirements(to: configuration, logger: logger)
        logger.contextualized(with: "version").debug(PeripheryVersion)
        let shell = ShellImpl(logger: logger) {
            logger.warn(
                "Termination can result in a corrupt index. Try the '--clean-build' flag if you get erroneous results such as false-positives and incorrect source file locations.",
                newlinePrefix: true // Print a newline after ^C
            )
        }
        let swiftVersion = SwiftVersion(shell: shell)
        logger.debug(swiftVersion.fullVersion)
        try swiftVersion.validateVersion()

        let project: Project = if configuration.guidedSetup {
            try GuidedSetup(configuration: configuration, shell: shell, logger: logger).perform()
        } else {
            try Project(configuration: configuration, shell: shell, logger: logger)
        }

        let updateChecker = UpdateChecker(logger: logger, configuration: configuration)
        updateChecker.run()

        let scanOutput = try Scan(
            configuration: configuration,
            logger: logger,
            swiftVersion: swiftVersion
        ).perform(project: project)

        let results = scanOutput.results
        let interval = logger.beginInterval("result:output")
        var baseline: Baseline?

        if let baselinePath = configuration.baseline {
            baseline = try Baseline.load(from: baselinePath)
        }

        let filteredResults = try OutputDeclarationFilter(configuration: configuration, logger: logger).filter(results, with: baseline)

        if let baselinePath = configuration.writeBaseline {
            let usrs = filteredResults
                .flatMapSet { $0.usrs }
                .union(baseline?.usrs ?? [])
            let baseline = Baseline.v1(usrs: usrs.sorted())
            let data = try JSONEncoder().encode(baseline)
            try data.write(to: baselinePath.url)
        }

        let outputFormat = configuration.outputFormat
        let formatter = outputFormat.formatter.init(configuration: configuration, logger: logger)
        let colored = outputFormat.supportsColoredOutput && logger.isColoredOutputEnabled

        let formattedOutput = try formatter.format(filteredResults, colored: colored)

        if let output = formattedOutput {
            if outputFormat.supportsAuxiliaryOutput {
                logger.info("", canQuiet: true)
            }

            logger.output(output)
        }

        if let resultsPath = configuration.writeResults {
            let output: String = if colored {
                // The formatted output contains ANSI escape codes, so we need to re-format
                // with coloring disabled.
                try formatter.format(filteredResults, colored: false) ?? ""
            } else {
                formattedOutput ?? ""
            }

            try output.write(to: resultsPath.url, atomically: true, encoding: .utf8)
        }

        logger.endInterval(interval)

        updateChecker.notifyIfAvailable()

        if !filteredResults.isEmpty, configuration.strict {
            throw PeripheryError.foundIssues(count: filteredResults.count)
        }
    }

    // MARK: - Private

    private static var projectRootDefault: FilePath {
        let bazelWorkspace = ProcessInfo.processInfo.environment["BUILD_WORKSPACE_DIRECTORY"]
        let root = bazelWorkspace ?? FileManager.default.currentDirectoryPath
        return FilePath(root)
    }
}

extension OutputFormat: ExpressibleByArgument {}
extension ColorOption: ExpressibleByArgument {}

extension FilePath: ArgumentParser.ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}

private extension Array {
    /// The array, or nil if it is empty. Repeatable options without a value given on the command line are empty.
    var nonEmpty: Self? {
        isEmpty ? nil : self
    }
}
