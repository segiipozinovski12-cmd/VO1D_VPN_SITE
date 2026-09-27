import SwiftUI
import NetworkExtension

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel

    @State private var rotateRing = false
    @State private var connectedAt: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 8)

                        connectionArea
                            .padding(.top, 26)

                        if model.vpn.isConnected {
                            connectedPanel
                                .padding(.top, 28)
                        } else {
                            serverPreview
                                .padding(.top, 28)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 26)
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
                updateAnimation(for: status)
                if status == .connected {
                    connectedAt = Date()
                } else if status == .disconnected || status == .invalid {
                    connectedAt = nil
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("VO1D_VPN")
                .font(.system(size: 23, weight: .bold, design: .monospaced))
                .tracking(1.2)

            Spacer()

            NavigationLink {
                ProfileView()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 34, height: 34)

                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var connectionArea: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(model.vpn.isConnected ? 0.08 : 0.045),
                                .black.opacity(0.15)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 188, height: 188)

                Circle()
                    .stroke(.white.opacity(model.vpn.isConnected ? 0.95 : 0.16), lineWidth: model.vpn.isConnected ? 4 : 2)
                    .frame(width: 188, height: 188)
                    .shadow(
                        color: .white.opacity(model.vpn.isConnected ? 0.58 : 0.07),
                        radius: model.vpn.isConnected ? 20 : 5
                    )

                if model.vpn.isBusy {
                    Circle()
                        .trim(from: 0.02, to: 0.28)
                        .stroke(
                            .white,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(rotateRing ? 360 : 0))

                    Circle()
                        .trim(from: 0.49, to: 0.67)
                        .stroke(
                            .white.opacity(0.42),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 174, height: 174)
                        .rotationEffect(.degrees(rotateRing ? -360 : 0))
                }

                Button {
                    Task { await model.toggleConnection() }
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 43, weight: .light))
                        .foregroundStyle(.white)
                        .frame(width: 145, height: 145)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                Text(connectionTitle)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)

                if model.vpn.isConnected, let connectedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(durationText(from: connectedAt, to: context.date))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.46))
                    }
                } else {
                    Text(connectionSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
        }
    }

    private var serverPreview: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Servers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()

                NavigationLink {
                    ServersView()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(model.servers.prefix(5).enumerated()), id: \.element.id) { index, server in
                    Button {
                        Task { await model.select(server) }
                    } label: {
                        serverRow(server, compact: true)
                    }
                    .buttonStyle(.plain)

                    if index < min(model.servers.count, 5) - 1 {
                        Divider()
                            .overlay(.white.opacity(0.07))
                            .padding(.leading, 42)
                    }
                }

                if model.servers.isEmpty {
                    Text("No locations available")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
    }

    private var connectedPanel: some View {
        VStack(spacing: 13) {
            NavigationLink {
                ServersView()
            } label: {
                HStack(spacing: 12) {
                    Text(model.selectedServer?.flag ?? "◌")
                        .font(.system(size: 25))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.selectedServer?.name ?? "Location")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(
                            model.selectedServer.map {
                                "\($0.code)  •  " + pingText(for: $0)
                            } ?? "—"
                        )
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 14)
                .frame(height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.055))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                infoRow("Your IP", value: "Protected")
                divider
                infoRow("Location", value: model.selectedServer?.name ?? "—")
                divider
                infoRow("Protocol", value: protocolLabel)
                divider
                infoRow("DNS", value: "Secure route")
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
        }
    }

    private func serverRow(_ server: VO1DServer, compact: Bool) -> some View {
        let selected = model.selectedServer?.code == server.code

        return HStack(spacing: 11) {
            Text(server.flag)
                .font(.system(size: compact ? 19 : 23))

            Text(server.name)
                .font(.system(size: compact ? 12 : 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Text(pingText(for: server))
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(pingColor(for: server))

            Circle()
                .fill(selected ? .white : .white.opacity(0.12))
                .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                .overlay {
                    if !selected {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }
                }
        }
        .frame(height: compact ? 38 : 48)
        .contentShape(Rectangle())
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
        }
        .frame(height: 40)
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.065))
    }

    private var connectionTitle: String {
        switch model.vpn.status {
        case .connected:
            return "Connect!"
        case .connecting, .reasserting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        default:
            return "Disconnected"
        }
    }

    private var connectionSubtitle: String {
        switch model.vpn.status {
        case .connecting, .reasserting:
            return "Establishing secure tunnel"
        case .disconnecting:
            return "Closing secure tunnel"
        default:
            return "Tap to connect"
        }
    }

    private var protocolLabel: String {
        guard let raw = model.selectedServer?.protocolName, !raw.isEmpty else {
            return "VLESS"
        }
        return raw.uppercased()
    }

    private func pingText(for server: VO1DServer) -> String {
        if let wrapped = model.pingByCode[server.code], let ping = wrapped {
            return "\(ping) ms"
        }
        return "— ms"
    }

    private func pingColor(for server: VO1DServer) -> Color {
        guard let wrapped = model.pingByCode[server.code], let ping = wrapped else {
            return .white.opacity(0.35)
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
        if status == .connecting || status == .reasserting || status == .disconnecting {
            rotateRing = false
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                    rotateRing = true
                }
            }
        } else {
            rotateRing = false
        }
    }
}
