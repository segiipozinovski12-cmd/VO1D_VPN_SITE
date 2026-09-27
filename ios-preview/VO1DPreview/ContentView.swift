import SwiftUI

struct PreviewServer: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let flag: String
    let basePing: Int
}

struct ContentView: View {
    @State private var connected = false
    @State private var connecting = false
    @State private var selectedCode = "RU"
    @State private var pings: [String:Int] = [:]
    @State private var showProfile = false
    @State private var pulse = false
    @State private var timer: Timer?

    @AppStorage("preview.nickname") private var nickname = "VO1D USER"
    @AppStorage("preview.autoconnect") private var autoConnect = false
    @AppStorage("preview.killswitch") private var killSwitch = true

    private let servers: [PreviewServer] = [
        .init(code: "RU", name: "Russia", flag: "🇷🇺", basePing: 38),
        .init(code: "DE", name: "Germany", flag: "🇩🇪", basePing: 54),
        .init(code: "NL", name: "Netherlands", flag: "🇳🇱", basePing: 61),
        .init(code: "FI", name: "Finland", flag: "🇫🇮", basePing: 66),
        .init(code: "UK", name: "United Kingdom", flag: "🇬🇧", basePing: 72)
    ]

    var selected: PreviewServer {
        servers.first(where: { $0.code == selectedCode }) ?? servers[0]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(white: 0.065), Color(white: 0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 22)
                connectControl
                Spacer(minLength: 20)
                locationList
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showProfile) {
            profileView
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            updatePings()
            timer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: true) { _ in
                updatePings()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("VO1D_VPN")
                    .font(.title3.monospaced().weight(.black))
                    .tracking(1.8)

                Text("INTERFACE PREVIEW")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.gray)
                    .tracking(1.4)
            }

            Spacer()

            Button {
                showProfile = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 31))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var connectControl: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .opacity(pulse ? 0.18 : 0.85)

                Circle()
                    .fill(Color.white.opacity(0.045))
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .frame(width: 178, height: 178)
                    .shadow(color: .white.opacity(connected ? 0.14 : 0.03), radius: 28)

                Button {
                    toggleConnection()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: connected ? "checkmark" : "power")
                            .font(.system(size: 46, weight: .light))

                        Text(connecting ? "CONNECTING…" : (connected ? "CONNECTED" : "CONNECT"))
                            .font(.caption.monospaced().weight(.bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 150, height: 150)
                    .contentShape(Circle())
                }
                .disabled(connecting)
            }

            VStack(spacing: 6) {
                Text(connected ? "connect!" : selected.name.uppercased())
                    .font(.headline.monospaced().weight(.bold))
                    .foregroundStyle(connected ? .white : .gray)

                Text("\(selected.flag) \(selected.code)  •  \(pings[selected.code] ?? selected.basePing) ms")
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray)
            }
        }
    }

    private var locationList: some View {
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
                    ForEach(servers) { server in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCode = server.code
                            }

                            if connected {
                                connected = false
                                connecting = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                    connected = true
                                    connecting = false
                                    animatePulse()
                                }
                            }
                        } label: {
                            HStack(spacing: 13) {
                                Text(server.flag)
                                    .font(.title3)
                                    .grayscale(1)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(server.name.uppercased())
                                        .font(.subheadline.monospaced().weight(.bold))
                                    Text("VO1D · \(server.code)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.gray)
                                }

                                Spacer()

                                Text("\(pings[server.code] ?? server.basePing) ms")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(.white)

                                Image(systemName: selectedCode == server.code ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCode == server.code ? .white : .gray.opacity(0.45))
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                            .background(
                                selectedCode == server.code
                                ? Color.white.opacity(0.10)
                                : Color.white.opacity(0.045),
                                in: RoundedRectangle(cornerRadius: 15)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(selectedCode == server.code ? 0.20 : 0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 290)
        }
    }

    private var profileView: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nickname", text: $nickname)
                                .font(.headline.monospaced().weight(.bold))
                            Text("PREVIEW ACCOUNT")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("CONNECTION") {
                    Toggle("Auto-connect", isOn: $autoConnect)
                    Toggle("Kill Switch", isOn: $killSwitch)
                }

                Section("SUBSCRIPTION") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("DEMO")
                            .font(.caption.monospaced().weight(.bold))
                    }
                    HStack {
                        Text("Remaining")
                        Spacer()
                        Text("7d 00h")
                            .font(.caption.monospaced())
                    }
                }

                Section {
                    Text("Это интерфейсная версия: кнопки и анимации работают локально, настоящий VPN-трафик здесь специально отключён.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("PROFILE")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func toggleConnection() {
        if connected {
            withAnimation(.easeInOut(duration: 0.25)) {
                connected = false
                pulse = false
            }
            return
        }

        connecting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeInOut(duration: 0.25)) {
                connecting = false
                connected = true
            }
            animatePulse()
        }
    }

    private func animatePulse() {
        pulse = false
        withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private func updatePings() {
        var next: [String:Int] = [:]
        for server in servers {
            next[server.code] = max(10, server.basePing + Int.random(in: -7...9))
        }
        pings = next
    }
}
