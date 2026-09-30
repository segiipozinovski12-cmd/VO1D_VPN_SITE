import XCTest
@testable import VO1D_VPN_PREVIEW

@MainActor
final class ConnectionTests: XCTestCase {
    private func model() -> AppViewModel {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(false, forKey: "vo1d.showLivePing")
        return AppViewModel(defaults: defaults)
    }
    private func wait(_ seconds: Double = 1.6) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
    func testFastestIsMeasuredAndCountryNeutral() {
        func server(_ code: String) -> VO1DServer {
            VO1DServer(id: code, code: code, name: code, flag: "", label: "", nodes: 1, probeHost: "", probePort: 443, protocolName: "VLESS")
        }
        let routes = [server("RU"), server("DE"), server("NL")]
        XCTAssertEqual(ServerRanking.fastest(routes, pings: ["DE": 31, "RU": 40])?.code, "DE")
        XCTAssertEqual(ServerRanking.fastest(routes, pings: ["DE": 31, "RU": 24])?.code, "RU")
        XCTAssertNil(ServerRanking.fastest(routes, pings: [:]))
        XCTAssertEqual(ServerRanking.sorted(routes, pings: ["DE": 31, "RU": 31]).map(\.code), ["DE", "RU", "NL"])
    }
    func testDemoConnectCancelSwitchAndLogout() async throws {
        let app = model()
        await app.bootstrap()
        XCTAssertNotNil(app.sessionToken)
        XCTAssertTrue(app.favoriteCodes.isEmpty)
        XCTAssertEqual(app.phase, .ready)
        app.toggleConnection()
        XCTAssertTrue(app.phase.isBusy)
        app.disconnect()
        try await wait()
        XCTAssertEqual(app.phase, .ready, "Cancelled work must not revive a connection")
        app.toggleConnection()
        try await wait()
        XCTAssertEqual(app.phase, .connected)
        let route = try XCTUnwrap(app.servers.first { $0.code != app.activeServer?.code })
        app.select(route)
        XCTAssertEqual(app.phase, .switching)
        try await wait(1.8)
        XCTAssertEqual(app.phase, .connected)
        XCTAssertEqual(app.activeServer?.code, route.code)
        await app.logout()
        try await wait(0.4)
        XCTAssertNil(app.sessionToken)
        XCTAssertEqual(app.session.stats.sessionSeconds, 0)
        XCTAssertEqual(app.phase, .ready)
        let activated = await app.activate(key: "")
        XCTAssertTrue(activated)
    }
    func testReconnectKeepsCurrentRoute() async throws {
        let app = model()
        await app.bootstrap()

        app.toggleConnection()
        try await wait()

        XCTAssertEqual(app.phase, .connected)
        let route = try XCTUnwrap(app.activeServer)

        app.reconnect()
        XCTAssertEqual(app.phase, .switching)

        try await wait(1.8)
        XCTAssertEqual(app.phase, .connected)
        XCTAssertEqual(app.activeServer?.code, route.code)

        app.disconnect()
    }

    func testStatsDoNotPublishThroughAppModel() async throws {
        let app = model()
        await app.bootstrap()
        app.toggleConnection()
        try await wait()
        var appChanges = 0
        var statChanges = 0
        let a = app.objectWillChange.sink { appChanges += 1 }
        let b = app.session.objectWillChange.sink { statChanges += 1 }
        let initial = app.session.stats
        try await wait(2.2)
        XCTAssertEqual(appChanges, 0)
        XCTAssertGreaterThan(statChanges, 0)
        XCTAssertLessThan(abs(app.session.stats.downloadMbps - initial.downloadMbps), 10)
        XCTAssertGreaterThan(app.session.stats.downloadedMB, initial.downloadedMB)
        a.cancel(); b.cancel()
        app.disconnect()
    }

    func testWaitUntilConnectedFailsFastWhenTunnelNeverStarts() async throws {
        let vpn = VPNManager()
        try await vpn.prepare()

        let started = ContinuousClock.now

        do {
            try await vpn.waitUntilConnected()
            XCTFail("A disconnected tunnel should not wait for the full connection timeout.")
        } catch {
            let elapsed = ContinuousClock.now - started
            XCTAssertLessThan(elapsed, .seconds(3))
        }
    }

    func testPreferencesAndFavoritesPersist() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let app = AppViewModel(defaults: defaults)
        await app.bootstrap()
        app.preferences.nickname = "VO1D TEST"
        app.preferences.compactServers = true
        app.preferences.secureDNS = false
        let route = try XCTUnwrap(app.servers.first)
        app.toggleFavorite(route)
        app.setForeground(false)
        let reopened = AppViewModel(defaults: defaults)
        XCTAssertEqual(reopened.preferences.nickname, "VO1D TEST")
        XCTAssertTrue(reopened.preferences.compactServers)
        XCTAssertFalse(reopened.preferences.connectionOptions.secureDNS)
        XCTAssertTrue(reopened.favoriteCodes.contains(route.code))
    }
}
