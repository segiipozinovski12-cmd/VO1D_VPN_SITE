import SwiftUI
import NetworkExtension

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(white: 0.075), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 22)
                powerControl
                Spacer(minLength: 24)
                serverList
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .sheet(isPresented: $model.showingProfile) {
            ProfileView()
                .environmentObject(model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "VO1D",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onChange(of: model.vpn.status) { _, newValue in
            if newValue == .connected {
                withAnimation(
                    .easeInOut(duration: 1.1)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("VO1D_VPN")
                    .font(.title3.monospaced().weight(.black))
                    .tracking(1.5)

                Text(
                    model.account?.active == true
                    ? "SUBSCRIPTION ACTIVE"
                    : "SUBSCRIPTION INACTIVE"
                )
                .font(.caption2.monospaced())
                .foregroundStyle(.gray)
            }

            Spacer()

            Button {
                model.showingProfile = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.top, 12)
    }

    private var powerControl: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(
                        Color.white.opacity(
                            model.vpn.isConnected ? 0.18 : 0.08
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 210, height: 210)
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .opacity(pulse ? 0.15 : 0.7)

                Circle()
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        Circle()
                            .stroke(
                                Color.white.opacity(0.18),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 176, height: 176)
                    .shadow(
                        color: .white.opacity(
                            model.vpn.isConnected ? 0.13 : 0.03
                        ),
                        radius: 28
                    )

                Button {
                    Task {
                        await model.toggleConnection()
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "power")
                            .font(.system(size: 45, weight: .light))

                        Text(model.connectionText)
                            .font(.caption.monospaced().weight(.bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 150, height: 150)
                    .contentShape(Circle())
                }
                .disabled(model.vpn.isBusy)
            }

            VStack(spacing: 5) {
                Text(
                    model.vpn.isConnected
                    ? "connect!"
                    : (model.selectedServer?.name ?? "SELECT LOCATION")
                )
                .font(.headline.monospaced().weight(.bold))
                .foregroundStyle(
                    model.vpn.isConnected ? .white : .gray
                )

                if let server = model.selectedServer {
                    let ping = model.pingByCode[server.code] ?? nil

                    Text(
                        "\(server.flag) \(server.code)  •  " +
                        (ping.map { "\($0) ms" } ?? "— ms")
                    )
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray)
                }
            }
        }
    }

    private var serverList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LOCATIONS")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.gray)

                Spacer()

                Text("LIVE PING")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.gray.opacity(0.7))
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.servers) { server in
                        serverRow(server)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 270)
        }
    }

    private func serverRow(_ server: VO1DServer) -> some View {
        let selected = model.selectedServer?.code == server.code
        let ping = model.pingByCode[server.code] ?? nil

        return Button {
            Task {
                await model.select(server)
            }
        } label: {
            HStack(spacing: 13) {
                Text(server.flag)
                    .font(.title3)
                    .grayscale(1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(server.name.uppercased())
                        .font(.subheadline.monospaced().weight(.bold))

                    Text(
                        "\(server.nodes) NODE" +
                        (server.nodes == 1 ? "" : "S")
                    )
                    .font(.caption2.monospaced())
                    .foregroundStyle(.gray)
                }

                Spacer()

                Text(ping.map { "\($0) ms" } ?? "—")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(ping == nil ? .gray : .white)

                Image(
                    systemName:
                        selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    selected
                    ? .white
                    : .gray.opacity(0.5)
                )
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                selected
                ? Color.white.opacity(0.10)
                : Color.white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 15)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        Color.white.opacity(
                            selected ? 0.20 : 0.08
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
