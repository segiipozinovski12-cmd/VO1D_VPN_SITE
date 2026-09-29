import XCTest
@testable import VO1D_VPN_PREVIEW

@MainActor
final class ConnectionTests: XCTestCase {
    private func model() -> AppViewModel {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(false, forKey: "vo1d.showLivePing")
        return AppViewModel(defaults: defaults)
    }

    private func wait(_ seconds: Double = 0.5) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    private func waitUntil(
        timeout: Double = 10,
        pollEvery: Double = 0.20,
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            try await Task.sleep(for: .seconds(pollEvery))
        }
    }

    func testFastestIsMeasuredAndCountryNeutral() {
        func server(_ code: String) -> VO1DServer {
            VO1DServer(
                id: code,
                code: code,
                name: code,
                flag: "",
                label: "",
                nodes: 1,
                probeHost: "",
                probePort: 443,
                protocolName: "VLESS"
            )
        }

        let routes = [
            server("RU"),
            server("DE"),
            server("NL")
        ]

        XCTAssertEqual(
            ServerRanking.fastest(
                routes,
                pings: ["DE": 31, "RU": 40]
            )?.code,
            "DE"
        )

        XCTAssertEqual(
            ServerRanking.fastest(
                routes,
                pings: ["DE": 31, "RU": 24]
            )?.code,
            "RU"
        )

        XCTAssertNil(
            ServerRanking.fastest(
                routes,
                pings: [:]
            )
        )

        XCTAssertEqual(
            ServerRanking.sorted(
                routes,
                pings: ["DE": 31, "RU": 31]
            ).map(\.code),
            ["DE", "RU", "NL"]
        )
    }

    func testEmbeddedAccessKeyVault() {
        XCTAssertEqual(AccessKeyVault.totalCount, 400)

        XCTAssertEqual(
            AccessKeyVault.license(
                for: "VOID-W8AU-VYWV-DM6A"
            )?.days,
            30
        )

        XCTAssertEqual(
            AccessKeyVault.license(
                for: "void-pdlp-59s3-nbq7"
            )?.days,
            90
        )

        XCTAssertEqual(
            AccessKeyVault.license(
                for: "VOID-Q97W-VYTY-MGA9"
            )?.days,
            180
        )

        XCTAssertEqual(
            AccessKeyVault.license(
                for: "VOID-6YL7-7Y8S-J6MF"
            )?.days,
            365
        )

        XCTAssertNil(
            AccessKeyVault.license(
                for: "VOID-XXXX-XXXX-XXXX"
            )
        )
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

        try await waitUntil {
            app.phase == .ready
        }

        XCTAssertEqual(
            app.phase,
            .ready,
            "Cancelled work must not revive a connection"
        )

        app.toggleConnection()

        try await waitUntil(timeout: 12) {
            app.phase == .connected
        }

        XCTAssertEqual(app.phase, .connected)

        let route = try XCTUnwrap(
            app.servers.first {
                $0.code != app.activeServer?.code
            }
        )

        app.select(route)

        XCTAssertTrue(
            app.phase == .switching ||
            app.phase.isBusy
        )

        try await waitUntil(timeout: 12) {
            app.phase == .connected &&
            app.activeServer?.code == route.code
        }

        XCTAssertEqual(app.phase, .connected)
        XCTAssertEqual(app.activeServer?.code, route.code)

        await app.logout()

        try await waitUntil(timeout: 5) {
            app.sessionToken == nil &&
            app.phase == .ready
        }

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

        try await waitUntil(timeout: 12) {
            app.phase == .connected &&
            app.activeServer != nil
        }

        XCTAssertEqual(app.phase, .connected)

        let route = try XCTUnwrap(app.activeServer)

        app.reconnect()

        XCTAssertTrue(
            app.phase == .switching ||
            app.phase.isBusy
        )

        try await waitUntil(timeout: 12) {
            app.phase == .connected &&
            app.activeServer?.code == route.code
        }

        XCTAssertEqual(app.phase, .connected)
        XCTAssertEqual(app.activeServer?.code, route.code)

        app.disconnect()
    }

    func testStatsDoNotPublishThroughAppModel() async throws {
        let app = model()
        await app.bootstrap()

        app.toggleConnection()

        try await waitUntil(timeout: 12) {
            app.phase == .connected
        }

        // Let connection-status callbacks settle before observing model churn.
        try await wait(0.45)

        var appChanges = 0
        var statChanges = 0

        let a = app.objectWillChange.sink {
            appChanges += 1
        }

        let b = app.session.objectWillChange.sink {
            statChanges += 1
        }

        let initial = app.session.stats

        try await wait(2.4)

        XCTAssertLessThanOrEqual(
            appChanges,
            1,
            "Live traffic should publish through SessionMonitor, not churn the whole AppViewModel."
        )

        XCTAssertGreaterThan(statChanges, 0)

        XCTAssertGreaterThanOrEqual(
            app.session.stats.downloadedMB,
            initial.downloadedMB
        )

        a.cancel()
        b.cancel()
        app.disconnect()
    }

    func testWaitUntilConnectedFailsFastWhenTunnelNeverStarts() async throws {
        let vpn = VPNManager()
        try await vpn.prepare()

        let started = ContinuousClock.now

        do {
            try await vpn.waitUntilConnected()
            XCTFail(
                "A disconnected tunnel should not wait for the full connection timeout."
            )
        } catch {
            let elapsed = ContinuousClock.now - started
            XCTAssertLessThan(elapsed, .seconds(3))
        }
    }

    func testPreferencesAndFavoritesPersist() async throws {
        let defaults = UserDefaults(
            suiteName: UUID().uuidString
        )!

        let app = AppViewModel(defaults: defaults)
        await app.bootstrap()

        app.preferences.nickname = "VO1D TEST"
        app.preferences.compactServers = true
        app.preferences.secureDNS = false

        let route = try XCTUnwrap(app.servers.first)
        app.toggleFavorite(route)
        app.setForeground(false)

        let reopened = AppViewModel(defaults: defaults)

        XCTAssertEqual(
            reopened.preferences.nickname,
            "VO1D TEST"
        )

        XCTAssertTrue(
            reopened.preferences.compactServers
        )

        XCTAssertFalse(
            reopened.preferences.connectionOptions.secureDNS
        )

        XCTAssertTrue(
            reopened.favoriteCodes.contains(route.code)
        )
    }
}
