import AppKit
import Observation

@MainActor
@Observable
final class UpdateController {
    enum State: Equatable {
        case idle, checking, upToDate, checkFailed, installing
        case installFailed(String)
    }

    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let launchDelay: TimeInterval = 5

    private(set) var state: State = .idle
    private(set) var release: Release? {
        didSet { onReleaseChange?() }
    }
    @ObservationIgnored var onReleaseChange: (() -> Void)?
    @ObservationIgnored private var timer: Timer?

    private let currentVersion = AppVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")

    func start() {
        Timer.scheduledTimer(withTimeInterval: Self.launchDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(manual: false) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(manual: false) }
        }
    }

    func check(manual: Bool = true) {
        guard state != .checking, state != .installing else { return }
        if manual { state = .checking }
        Task {
            do {
                let latest = try await GitHubRelease.fetchLatest()
                if let currentVersion, latest.version > currentVersion {
                    release = latest
                    state = .idle
                } else {
                    state = .upToDate
                }
            } catch {
                if manual { state = .checkFailed }
            }
        }
    }

    func install() {
        guard let release, state != .installing else { return }
        state = .installing
        let target = Bundle.main.bundleURL
        Task {
            do {
                let app = try await UpdateInstaller.download(release, replacing: target)
                try UpdateInstaller.replace(target, with: app)
                try UpdateInstaller.relaunch(target, after: ProcessInfo.processInfo.processIdentifier)
                NSApp.terminate(nil)
            } catch {
                state = .installFailed(error.localizedDescription)
            }
        }
    }

    func openReleasePage() {
        guard let release else { return }
        NSWorkspace.shared.open(release.pageURL)
    }
}
