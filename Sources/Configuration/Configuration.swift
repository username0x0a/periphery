import Extensions
import FilenameMatcher
import Foundation
import Logger
import Shared
import SystemPackage
import Yams

public final class Configuration {
    public static var defaultConfigurationFile = FilePath(".periphery.yml")

    public init() {}

    @Setting(key: "project", defaultValue: nil, convert: SettingConverter.filePath)
    public var project: FilePath?

    @Setting(key: "format", defaultValue: .default)
    public var outputFormat: OutputFormat

    @Setting(key: "schemes", defaultValue: [])
    public var schemes: [String]

    @Setting(key: "exclude_tests", defaultValue: false)
    public var excludeTests: Bool

    @Setting(key: "exclude_targets", defaultValue: [])
    public var excludeTargets: [String]

    @Setting(key: "index_exclude", defaultValue: ["**/*?.build/**/*", "**/SourcePackages/checkouts/**"], requireDefaultValues: true)
    public var indexExclude: [String]

    @Setting(key: "report_exclude", defaultValue: [])
    public var reportExclude: [String]

    @Setting(key: "report_include", defaultValue: [])
    public var reportInclude: [String]

    @Setting(key: "build_arguments", defaultValue: [])
    public var buildArguments: [String]

    @Setting(key: "xcode_list_arguments", defaultValue: [])
    public var xcodeListArguments: [String]

    @Setting(key: "retain_assign_only_property_types", defaultValue: [])
    public var retainAssignOnlyPropertyTypes: [String]

    @Setting(key: "external_encodable_protocols", defaultValue: [])
    public var externalEncodableProtocols: [String]

    @Setting(key: "external_codable_protocols", defaultValue: [])
    public var externalCodableProtocols: [String]

    @Setting(key: "external_test_case_classes", defaultValue: [])
    public var externalTestCaseClasses: [String]

    @Setting(key: "retain_objc_accessible", defaultValue: false)
    public var retainObjcAccessible: Bool

    @Setting(key: "retain_objc_annotated", defaultValue: false)
    public var retainObjcAnnotated: Bool

    @Setting(key: "retain_files", defaultValue: [])
    public var retainFiles: [String]

    @Setting(key: "retain_public", defaultValue: false)
    public var retainPublic: Bool

    @Setting(key: "no_retain_spi", defaultValue: [])
    public var noRetainSPI: [String]

    @Setting(key: "retain_assign_only_properties", defaultValue: false)
    public var retainAssignOnlyProperties: Bool

    @Setting(key: "retain_unused_protocol_func_params", defaultValue: false)
    public var retainUnusedProtocolFuncParams: Bool

    @Setting(key: "retain_swift_ui_previews", defaultValue: false)
    public var retainSwiftUIPreviews: Bool

    @Setting(key: "disable_redundant_public_analysis", defaultValue: false)
    public var disableRedundantPublicAnalysis: Bool

    @Setting(key: "disable_unused_import_analysis", defaultValue: false)
    public var disableUnusedImportAnalysis: Bool

    @Setting(key: "superfluous_ignore_comments", defaultValue: true)
    public var superfluousIgnoreComments: Bool

    @Setting(key: "retain_unused_imported_modules", defaultValue: [])
    public var retainUnusedImportedModules: [String]

    @Setting(key: "retain_codable_properties", defaultValue: false)
    public var retainCodableProperties: Bool

    @Setting(key: "retain_encodable_properties", defaultValue: false)
    public var retainEncodableProperties: Bool

    @Setting(key: "retain_equatable_properties", defaultValue: false)
    public var retainEquatableProperties: Bool

    @Setting(key: "retain_hashable_properties", defaultValue: false)
    public var retainHashableProperties: Bool

    @Setting(key: "verbose", defaultValue: false)
    public var verbose: Bool

    @Setting(key: "quiet", defaultValue: false)
    public var quiet: Bool

    @Setting(key: "color", defaultValue: .default)
    public var color: ColorOption

    @Setting(key: "disable_update_check", defaultValue: false)
    public var disableUpdateCheck: Bool

    @Setting(key: "strict", defaultValue: false)
    public var strict: Bool

    @Setting(key: "index_store_path", defaultValue: [], convert: SettingConverter.filePathList)
    public var indexStorePath: [FilePath]

    @Setting(key: "skip_build", defaultValue: false)
    public var skipBuild: Bool

    @Setting(key: "clean_build", defaultValue: false)
    public var cleanBuild: Bool

    @Setting(key: "relative_results", defaultValue: false)
    public var relativeResults: Bool

    @Setting(key: "json_package_manifest_path", defaultValue: nil, convert: SettingConverter.filePath)
    public var jsonPackageManifestPath: FilePath?

    @Setting(key: "baseline", defaultValue: nil, convert: SettingConverter.filePath)
    public var baseline: FilePath?

    @Setting(key: "write_baseline", defaultValue: nil, convert: SettingConverter.filePath)
    public var writeBaseline: FilePath?

    @Setting(key: "write_results", defaultValue: nil, convert: SettingConverter.filePath)
    public var writeResults: FilePath?

    @Setting(key: "generic_project_config", defaultValue: nil, convert: SettingConverter.filePath)
    public var genericProjectConfig: FilePath?

    @Setting(key: "bazel", defaultValue: false)
    public var bazel: Bool

    @Setting(key: "bazel_filter", defaultValue: nil)
    public var bazelFilter: String?

    @Setting(key: "bazel_query", defaultValue: nil)
    public var bazelQuery: String?

    @Setting(key: "bazel_index_store", defaultValue: nil, convert: SettingConverter.filePath)
    public var bazelIndexStore: FilePath?

    @Setting(key: "bazel_check_visibility", defaultValue: false)
    public var bazelCheckVisibility: Bool

    // Non user facing.
    public var guidedSetup: Bool = false
    public var projectRoot: FilePath = .init()

    public var hasNonDefaultValues: Bool {
        settings.contains(where: \.hasNonDefaultValue)
    }

    public func asYaml() throws -> String {
        var config: [String: Any?] = [:]

        for setting in settings where setting.hasNonDefaultValue {
            config[setting.key] = setting.wrappedValue
        }

        return try Yams.dump(object: config)
    }

    public func save(to path: FilePath = defaultConfigurationFile) throws {
        let data = try asYaml().data(using: .utf8)
        FileManager.default.createFile(atPath: path.string, contents: data)
    }

    /// Loads the configuration file. A value that is not valid for its setting, and a key that is not a setting, are
    /// reported to `warn` and ignored, an unreadable file or a document that is not a mapping is an error.
    public func load(from path: FilePath?, warn: ((String) -> Void)? = nil) throws {
        guard let path = try configurationPath(withUserProvided: path) else { return }

        let encodedYAML = try String(contentsOf: path.url, encoding: .utf8)
        let logger = Logger(quiet: false, verbose: false, colorMode: .never)
        let warn = warn ?? { logger.warn($0) }

        // An empty document is an empty configuration.
        guard let document = try Yams.load(yaml: encodedYAML) else { return }
        guard let yaml = document as? [AnyHashable: Any] else {
            throw PeripheryError.usageError("\(path.string): the configuration must be a mapping of keys to values, got \(SettingValueError.describe(document))")
        }

        let entries = yaml.map { (key: "\($0.key.base)", value: $0.value, isString: $0.key.base is String) }.sorted { $0.key < $1.key }

        for (key, value, isString) in entries {
            if isString, let setting = settings.first(where: { key == $0.key }) {
                if let message = setting.assign(value) {
                    warn("\(path.string): \(message)")
                }
            } else if isString, let suggestion = closestSettingKey(to: key) {
                warn("\(path.string): invalid key '\(key)' (did you mean '\(suggestion)'?)")
            } else {
                warn("\(path.string): invalid key '\(key)'")
            }
        }
    }

    // MARK: - Helpers

    /// Applies a value given on the command line, which takes precedence over the configuration file, even when it is
    /// the default value. A nil value was not given, and leaves the setting unchanged.
    public func apply<T: Equatable>(_ path: KeyPath<Configuration, Setting<T>>, _ value: T?) {
        guard let value else { return }

        self[keyPath: path].wrappedValue = value
    }

    public func apply<T: Equatable>(_ path: KeyPath<Configuration, Setting<T?>>, _ value: T?) {
        guard let value else { return }

        self[keyPath: path].wrappedValue = value
    }

    public func buildFilenameMatchers() {
        indexExcludeMatchers = buildFilenameMatchers(with: indexExclude)
        retainFilesMatchers = buildFilenameMatchers(with: retainFiles)
        reportExcludeMatchers = buildFilenameMatchers(with: reportExclude)
        reportIncludeMatchers = buildFilenameMatchers(with: reportInclude)
    }

    public var indexExcludeMatchers: [FilenameMatcher] = []
    public var retainFilesMatchers: [FilenameMatcher] = []
    public var reportExcludeMatchers: [FilenameMatcher] = []
    public var reportIncludeMatchers: [FilenameMatcher] = []

    // MARK: - Private

    /// The setting key that a misspelt key most likely stands for, if any is close enough.
    private func closestSettingKey(to key: String) -> String? {
        let normalized = key.lowercased().replacingOccurrences(of: "-", with: "_")
        let candidates = settings.map(\.key).sorted()

        if let exact = candidates.first(where: { $0 == normalized }) {
            return exact
        }

        let maxDistance = min(3, max(1, key.count / 4))
        let ranked = candidates.map { (key: $0, distance: Self.editDistance(normalized, $0)) }

        return ranked.filter { $0.distance <= maxDistance }.min { $0.distance < $1.distance }?.key
    }

    /// The Levenshtein distance between two strings.
    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        var previous = Array(0 ... rhs.count)

        for (i, l) in lhs.enumerated() {
            var current = [i + 1]

            for (j, r) in rhs.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (l == r ? 0 : 1)))
            }

            previous = current
        }

        return previous[rhs.count]
    }

    lazy var settings: [any AbstractSetting] = [
        $project, $schemes, $excludeTargets, $excludeTests, $indexExclude, $reportExclude, $reportInclude, $outputFormat,
        $retainPublic, $noRetainSPI, $retainFiles, $retainAssignOnlyProperties, $retainAssignOnlyPropertyTypes, $retainObjcAccessible,
        $retainObjcAnnotated, $retainUnusedProtocolFuncParams, $retainSwiftUIPreviews, $disableRedundantPublicAnalysis,
        $disableUnusedImportAnalysis, $superfluousIgnoreComments, $retainUnusedImportedModules,
        $externalEncodableProtocols, $externalCodableProtocols, $externalTestCaseClasses, $verbose, $quiet, $color,
        $disableUpdateCheck, $strict, $indexStorePath,
        $skipBuild, $cleanBuild, $buildArguments, $xcodeListArguments, $relativeResults,
        $jsonPackageManifestPath, $retainCodableProperties, $retainEncodableProperties, $retainEquatableProperties,
        $retainHashableProperties, $baseline, $writeBaseline,
        $writeResults, $genericProjectConfig, $bazel, $bazelFilter, $bazelQuery, $bazelIndexStore, $bazelCheckVisibility,
    ]

    private func buildFilenameMatchers(with patterns: [String]) -> [FilenameMatcher] {
        // TODO: respect filesystem case sensitivity.
        let pwd = FilePath.current.string
        return patterns.map { FilenameMatcher(relativePattern: $0, to: pwd, caseSensitive: false) }
    }

    private func configurationPath(withUserProvided path: FilePath?) throws -> FilePath? {
        if let path {
            if !path.exists {
                throw PeripheryError.pathDoesNotExist(path: path.lexicallyNormalized().string)
            }

            return path
        }

        return [Self.defaultConfigurationFile, FilePath(".periphery.yaml")].first { $0.exists }
    }
}

// MARK: - Yaml Encoding

extension OutputFormat: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        rawValue.represented()
    }
}

extension FilePath: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        string.represented()
    }
}

extension ColorOption: Yams.ScalarRepresentable {
    public func represented() -> Node.Scalar {
        rawValue.represented()
    }
}
