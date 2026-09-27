import SwiftUI
import NetworkExtension

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel

    @AppStorage("vo1d.reduceAnimations") private var reduceAnimations = false
    @AppStorage("vo1d.showLivePing") private var showLivePing = true

    @State private var ringSpin = false
    @State private var connectedPulse = false
    @State private var connectedAt: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 8)

                        connectionHero
                            .padding(.top, 20)

                        quickControls
                            .padding(.top, 22)

                        Group {
                            if model.vpn.isConnected {
                                connectedDashboard
                            } else {
                                serverPreview
                            }
                        }
                        .padding(.top, 20)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            )
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "VO1D",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .onAppear {
                updateAnimation(for: model.vpn.status)
                if model.vpn.isConnected, connectedAt == nil {
                    connectedAt = Date()
                }
            }
            .onChange(of: model.vpn.status) { _, status in
                withAnimation(.snappy(duration: 0.34)) {
                    updateAnimation(for: status)
                    if status == .connected {
                        connectedAt = Date()
                    } else if status == .disconnected || status == .invalid {
                        connectedAt = nil
                    }
                }
            }
            .animation(.snappy(duration: 0.34), value: model.vpn.status)
        }
    }

    private var background: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    .white.opacity(model.vpn.isConnected ? 0.035 : 0.018),
                    .clear,
                    .white.opacity(0.012)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("VO1D_VPN")
                    .font(.system(size: 23, weight: .bold, design: .monospaced))
                    .tracking(1.2)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)

                    Text(statusSmallText)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            if model.isDemoMode {
                Text("DEMO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.07))
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
                    .foregroundStyle(.white.opacity(0.58))
            }

            NavigationLink {
                ProfileView()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 36, height: 36)

                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var connectionHero: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(model.vpn.isConnected ? 0.085 : 0.035),
                                .white.opacity(0.01),
                                .clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 115
                        )
                    )
                    .frame(width: 230, height: 230)

                Circle()
                    .stroke(.white.opacity(0.055), lineWidth: 1)
                    .frame(width: 214, height: 214)

                if model.vpn.isConnected {
                    Circle()
                        .stroke(.white.opacity(connectedPulse ? 0.11 : 0.34), lineWidth: 1)
                        .frame(width: connectedPulse ? 228 : 202, height: connectedPulse ? 228 : 202)

                    Circle()
                        .stroke(.white.opacity(0.92), lineWidth: 3.5)
                        .frame(width: 184, height: 184)
                        .shadow(color: .white.opacity(0.36), radius: 14)
                } else {
                    Circle()
                        .stroke(.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 184, height: 184)
                }

                if model.vpn.isBusy {
                    Circle()
                        .trim(from: 0.02, to: 0.30)
                        .stroke(
                            .white,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 202, height: 202)
                        .rotationEffect(.degrees(ringSpin ? 360 : 0))

                    Circle()
                        .trim(from: 0.52, to: 0.69)
                        .stroke(
                            .white.opacity(0.38),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                        )
                        .frame(width: 170, height: 170)
                        .rotationEffect(.degrees(ringSpin ? -360 : 0))
                }

                Button {
                    Task { await model.toggleConnection() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(model.vpn.isConnected ? 0.09 : 0.04))
                            .frame(width: 145, height: 145)

                        Image(systemName: model.vpn.isConnected ? "checkmark" : "power")
                            .font(.system(size: 43, weight: .light))
                            .foregroundStyle(.white)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.92))
                .disabled(model.vpn.isBusy)
            }
            .frame(height: 230)

            VStack(spacing: 5) {
                Text(connectionTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .contentTransition(.opacity)

                if model.vpn.isConnected, let connectedAt {
                    HStack(spacing: 8) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(durationText(from: connectedAt, to: context.date))
                                .contentTransition(.numericText())
                        }

                        Text("•")
                            .foregroundStyle(.white.opacity(0.25))

                        Text(model.selectedServer?.name ?? "—")
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                } else {
                    Text(connectionSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.46))
                }

                if showLivePing, let server = model.selectedServer {
                    HStack(spacing: 5) {
                        Text(server.flag)
                        Text(server.code)
                        Text("•")
                        Text(pingText(for: server))
                            .contentTransition(.numericText())
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.34))
                    .padding(.top, 2)
                }
            }
        }
    }

    private var quickControls: some View {
        HStack(spacing: 8) {
            quickButton(
                icon: "bolt.fill",
                title: "FASTEST",
                subtitle: fastestSubtitle
            ) {
                Task { await model.connectFastest() }
            }

            quickButton(
                icon: "arrow.clockwise",
                title: "PING",
                subtitle: model.isRefreshingPings ? "CHECKING" : "REFRESH"
            ) {
                Task { await model.refreshPingsNow() }
            }

            quickButton(
                icon: model.autoConnect ? "a.circle.fill" : "a.circle",
                title: "AUTO",
                subtitle: model.autoConnect ? "ON" : "OFF"
            ) {
                withAnimation(.snappy(duration: 0.25)) {
                    model.autoConnect.toggle()
                }
            }
        }
    }

    private func quickButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolEffect(.pulse, value: model.isRefreshingPings && title == "PING")

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.7)

                Text(subtitle)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.075), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96))
    }

    private var serverPreview: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Servers")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Choose a location or use Fastest")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.32))
                }

                Spacer()

                NavigationLink {
                    ServersView()
                } label: {
                    HStack(spacing: 5) {
                        Text("ALL")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.055))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(spacing: 0) {
                ForEach(Array(model.servers.prefix(5).enumerated()), id: \.element.id) { index, server in
                    Button {
                        Task { await model.select(server) }
                    } label: {
                        serverRow(server)
                    }
                    .buttonStyle(.plain)

                    if index < min(model.servers.count, 5) - 1 {
                        Divider()
                            .overlay(.white.opacity(0.055))
                            .padding(.leading, 42)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(cardBackground)
        }
    }

    private var connectedDashboard: some View {
        VStack(spacing: 12) {
            statsGrid

            NavigationLink {
                ServersView()
            } label: {
                HStack(spacing: 12) {
                    Text(model.selectedServer?.flag ?? "◌")
                        .font(.system(size: 26))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.selectedServer?.name ?? "Location")
                            .font(.system(size: 15, weight: .semibold))

                        Text(
                            model.selectedServer.map {
                                "\($0.code)  •  " + pingText(for: $0)
                            } ?? "—"
                        )
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.40))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(model.connectionQuality)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(qualityColor)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 68)
                .background(cardBackground)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.98))

            VStack(spacing: 0) {
                infoRow("Your IP", value: model.isDemoMode ? "185.83.24.112" : "Protected")
                divider
                infoRow("Protocol", value: protocolLabel)
                divider
                infoRow("DNS", value: "Secure route")
                divider
                infoRow("Kill Switch", value: model.killSwitch ? "Enabled" : "Disabled")
            }
            .padding(.horizontal, 14)
            .background(cardBackground)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 8) {
            statCard(
                icon: "arrow.down",
                value: String(format: "%.1f", model.liveStats.downloadMbps),
                unit: "Mbps",
                title: "DOWNLOAD"
            )

            statCard(
                icon: "arrow.up",
                value: String(format: "%.1f", model.liveStats.uploadMbps),
                unit: "Mbps",
                title: "UPLOAD"
            )

            statCard(
                icon: "waveform.path.ecg",
                value: model.currentPing.map(String.init) ?? "—",
                unit: "ms",
                title: "PING"
            )
        }
    }

    private func statCard(
        icon: String,
        value: String,
        unit: String,
        title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())

                Text(unit)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.36))
            }

            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.34))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBackground)
    }

    private func serverRow(_ server: VO1DServer) -> some View {
        let selected = model.selectedServer?.code == server.code

        return HStack(spacing: 11) {
            Text(server.flag)
                .font(.system(size: 19))

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.system(size: 12, weight: .medium))

                Text(server.label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.27))
            }

            Spacer()

            if model.isFavorite(server) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.38))
            }

            if showLivePing {
                Text(pingText(for: server))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(pingColor(for: server))
                    .contentTransition(.numericText())
            }

            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(selected ? .white : .white.opacity(0.18))
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(height: 40)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white.opacity(0.038))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.055))
    }

    private var statusSmallText: String {
        switch model.vpn.status {
        case .connected: return "SECURE CONNECTION"
        case .connecting, .reasserting: return "ESTABLISHING TUNNEL"
        case .disconnecting: return "CLOSING TUNNEL"
        default: return "READY"
        }
    }

    private var statusDotColor: Color {
        switch model.vpn.status {
        case .connected: return Color(red: 0.38, green: 0.88, blue: 0.48)
        case .connecting, .reasserting, .disconnecting: return .white.opacity(0.75)
        default: return .white.opacity(0.24)
        }
    }

    private var connectionTitle: String {
        switch model.vpn.status {
        case .connected: return "Connected"
        case .connecting, .reasserting: return "Connecting..."
        case .disconnecting: return "Disconnecting..."
        default: return "Disconnected"
        }
    }

    private var connectionSubtitle: String {
        switch model.vpn.status {
        case .connecting, .reasserting: return "Establishing secure tunnel"
        case .disconnecting: return "Closing secure tunnel"
        default: return "Tap to connect"
        }
    }

    private var protocolLabel: String {
        guard let raw = model.selectedServer?.protocolName, !raw.isEmpty else {
            return "VLESS"
        }
        return raw.uppercased()
    }

    private var fastestSubtitle: String {
        guard let server = model.fastestServer else { return "FIND" }
        return server.code
    }

    private var qualityColor: Color {
        switch model.connectionQuality {
        case "EXCELLENT": return Color(red: 0.38, green: 0.88, blue: 0.48)
        case "GOOD": return Color(red: 0.60, green: 0.86, blue: 0.46)
        case "FAIR": return Color(red: 0.93, green: 0.78, blue: 0.34)
        default: return Color(red: 0.94, green: 0.40, blue: 0.40)
        }
    }

    private func pingText(for server: VO1DServer) -> String {
        if let wrapped = model.pingByCode[server.code], let ping = wrapped {
            return "\(ping) ms"
        }
        return "— ms"
    }

    private func pingColor(for server: VO1DServer) -> Color {
        guard let wrapped = model.pingByCode[server.code], let ping = wrapped else {
            return .white.opacity(0.32)
        }

        if ping < 70 { return Color(red: 0.38, green: 0.86, blue: 0.46) }
        if ping < 110 { return Color(red: 0.92, green: 0.78, blue: 0.33) }
        return Color(red: 0.95, green: 0.38, blue: 0.38)
    }

    private func durationText(from start: Date, to end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func updateAnimation(for status: NEVPNStatus) {
        ringSpin = false
        connectedPulse = false

        guard !reduceAnimations else { return }

        if status == .connecting || status == .reasserting || status == .disconnecting {
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    ringSpin = true
                }
            }
        }

        if status == .connected {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    connectedPulse = true
                }
            }
        }
    }
}
