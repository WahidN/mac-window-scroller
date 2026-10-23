import Foundation

struct Release: Equatable {
    let version: AppVersion
    let pageURL: URL
    let zipURL: URL
}

enum GitHubRelease {
    private static let latestURL = URL(string: "https://api.github.com/repos/WahidN/mac-window-scroller/releases/latest")!

    private struct Response: Decodable {
        struct Asset: Decodable {
            let browser_download_url: URL
        }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    static func fetchLatest() async throws -> Release {
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> Release {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let version = AppVersion(response.tag_name),
              let zip = response.assets.first(where: { $0.browser_download_url.pathExtension == "zip" })
        else { throw URLError(.cannotParseResponse) }
        return Release(version: version, pageURL: response.html_url, zipURL: zip.browser_download_url)
    }
}
