import Configuration
import Foundation
import Logger
import Shared

#if canImport(FoundationNetworking)
    import FoundationNetworking
    import Synchronization

    /// Deallocating a URLSession on Linux crashes with Foundation in Swift 6.4 ("_MultiHandle deallocated with
    /// non-zero retain count"). Sessions are therefore kept alive until the process exits.
    enum URLSessionRetainer {
        private static let sessions = Mutex<[URLSession]>([])

        static func retain(_ session: URLSession) {
            sessions.withLock { $0.append(session) }
        }
    }
#endif

final class UpdateChecker {
    private static let repository = "username0x0a/periphery"

    private let logger: Logger
    private let debugLogger: ContextualLogger
    private let configuration: Configuration
    private let urlSession: URLSession
    private let latestReleaseURL: URL
    private var latestVersion: String?
    private let semaphore: DispatchSemaphore
    private var error: Error?

    required init(logger: Logger, configuration: Configuration) {
        self.logger = logger
        debugLogger = logger.contextualized(with: "update-check")
        self.configuration = configuration
        let config = URLSessionConfiguration.ephemeral
        urlSession = URLSession(configuration: config)
        latestReleaseURL = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!
        semaphore = DispatchSemaphore(value: 0)
    }

    deinit {
        #if canImport(FoundationNetworking)
            URLSessionRetainer.retain(urlSession)
        #else
            urlSession.invalidateAndCancel()
        #endif
    }

    func run() {
        // We only perform the update check with xcode format because it may interfere with
        // parsing json and csv.
        guard !configuration.disableUpdateCheck,
              configuration.outputFormat.supportsAuxiliaryOutput else { return }

        var urlRequest = URLRequest(url: latestReleaseURL)
        urlRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let task = urlSession.dataTask(with: urlRequest) { [weak self] data, _, error in
            guard let self else { return }

            if let error {
                debugLogger.debug("error: \(error.localizedDescription)")
                self.error = error
                semaphore.signal()
                return
            }

            guard let jsonData = data,
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [AnyHashable: Any],
                  let tagName = jsonObject["tag_name"] as? String
            else {
                var json = "N/A"

                if let data, let decoded = String(bytes: data, encoding: .utf8) {
                    json = decoded
                }

                let message = "Failed to identify latest release tag in: \(json)"
                self.error = PeripheryError.updateCheckError(message: message)
                debugLogger.debug(message)
                semaphore.signal()
                return
            }

            latestVersion = tagName
            semaphore.signal()
        }

        task.resume()
    }

    func notifyIfAvailable() {
        guard let latestVersion else { return }

        debugLogger.debug("latest: \(latestVersion)")

        guard latestVersion.isVersion(greaterThan: PeripheryVersion) else { return }

        logger.info(logger.colorize("\nUpdate Available!", .boldGreen))
        let boldLatestVersion = logger.colorize(latestVersion, .bold)
        let boldLocalVersion = logger.colorize(PeripheryVersion, .bold)
        logger.info("Version \(boldLatestVersion) is now available, you are using version \(boldLocalVersion).")
        logger.info("Release notes: " + logger.colorize("https://github.com/\(Self.repository)/releases/tag/\(latestVersion)", .bold))
        let boldOption = logger.colorize("--disable-update-check", .bold)
        let boldScan = logger.colorize("scan", .bold)
        logger.info("To disable update checks pass the \(boldOption) option to the \(boldScan) command.")

        logger.info(logger.colorize("\nIf you are enjoying Periphery, please consider becoming a sponsor.", .bold) + "\nYour support helps ensure the continued development of new features and updates to support new Swift versions.\n" + logger.colorize("https://github.com/sponsors/peripheryapp", .boldMagenta))
    }

    func wait() -> Result<String, PeripheryError> {
        let waitResult = semaphore.wait(timeout: .now() + 60)

        if let error {
            return .failure(.underlyingError(error))
        }

        if waitResult == .timedOut {
            return .failure(PeripheryError.updateCheckError(message: "Timed out while checking for update."))
        }

        if let latestVersion {
            return .success(latestVersion)
        }

        return .failure(PeripheryError.updateCheckError(message: "Failed to determine latest version."))
    }
}
