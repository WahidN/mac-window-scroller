import Testing
@testable import WindowCarousel

struct AppVersionTests {
    @Test func higherVersionIsNewer() throws {
        #expect(try #require(AppVersion("0.5.0")) > #require(AppVersion("0.4.0")))
    }

    @Test func sameVersionIsNotNewer() throws {
        #expect(try #require(AppVersion("0.4.0")) == #require(AppVersion("0.4.0")))
        #expect(try #require(AppVersion("0.4")) == #require(AppVersion("0.4.0")))
    }

    @Test func lowerVersionIsOlder() throws {
        #expect(try #require(AppVersion("0.3.9")) < #require(AppVersion("0.4.0")))
    }

    @Test func comparesNumbersNotText() throws {
        #expect(try #require(AppVersion("0.10.0")) > #require(AppVersion("0.9.0")))
    }

    @Test func stripsLeadingV() throws {
        #expect(try #require(AppVersion("v0.5.0")).parts == [0, 5, 0])
    }

    @Test func rejectsTextThatIsNotAVersion() {
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("") == nil)
    }
}
