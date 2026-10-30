import Foundation
import Testing
@testable import WindowCarousel

struct GitHubReleaseTests {
    @Test func readsVersionPageAndZip() throws {
        let json = """
        {
          "tag_name": "v0.4.0",
          "html_url": "https://github.com/WahidN/mac-window-scroller/releases/tag/v0.4.0",
          "assets": [
            {"browser_download_url": "https://github.com/WahidN/mac-window-scroller/releases/download/v0.4.0/notes.txt"},
            {"browser_download_url": "https://github.com/WahidN/mac-window-scroller/releases/download/v0.4.0/WindowCarousel-0.4.0.zip"}
          ]
        }
        """
        let release = try GitHubRelease.parse(Data(json.utf8))

        #expect(release.version == AppVersion("0.4.0"))
        #expect(release.pageURL.absoluteString.hasSuffix("/tag/v0.4.0"))
        #expect(release.zipURL.lastPathComponent == "WindowCarousel-0.4.0.zip")
    }

    @Test func failsWithoutAZip() {
        let json = #"{"tag_name": "v0.4.0", "html_url": "https://github.com", "assets": []}"#

        #expect(throws: (any Error).self) { try GitHubRelease.parse(Data(json.utf8)) }
    }
}
