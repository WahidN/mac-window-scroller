import Foundation
import Security

struct UpdateError: LocalizedError {
    let errorDescription: String?
}

enum UpdateInstaller {
    static func download(_ release: Release, replacing target: URL) async throws -> URL {
        let folder = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true
        )
        let (zip, _) = try await URLSession.shared.download(from: release.zipURL)
        try run("/usr/bin/ditto", "-x", "-k", zip.path, folder.path)
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        guard let app = items.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError(errorDescription: "The download has no app inside.")
        }
        try verifySignature(of: app, matches: target)
        return app
    }

    static func verifySignature(of app: URL, matches target: URL) throws {
        var requirement: SecRequirement?
        guard let targetCode = staticCode(at: target),
              SecCodeCopyDesignatedRequirement(targetCode, [], &requirement) == errSecSuccess,
              let requirement,
              let appCode = staticCode(at: app),
              SecStaticCodeCheckValidity(appCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement) == errSecSuccess
        else {
            throw UpdateError(errorDescription: "The update is not signed by the same developer.")
        }
    }

    static func replace(_ target: URL, with app: URL) throws {
        _ = try FileManager.default.replaceItemAt(target, withItemAt: app)
    }

    static func relaunch(_ app: URL, after pid: Int32) throws {
        // Waits for the old process to quit, so the new one can claim the hotkeys and the event tap
        try run("/bin/sh", "-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; open \"$0\"", app.path, wait: false)
    }

    private static func staticCode(at url: URL) -> SecStaticCode? {
        var code: SecStaticCode?
        return SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess ? code : nil
    }

    private static func run(_ tool: String, _ arguments: String..., wait: Bool = true) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        guard wait else { return }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw UpdateError(errorDescription: "Couldn't unpack the update.")
        }
    }
}
