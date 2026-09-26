import SwiftUI


struct SavedCall: Identifiable, Equatable {
    let id: UUID
    var url: String

    init(id: UUID = UUID(), url: String = "") {
        self.id = id
        self.url = url
    }
}


struct ContentView: View {
    @EnvironmentObject var proxyManager: ProxyManager

    @State private var savedCalls: [SavedCall]

    @State private var showSettings = false
    @State private var activeCallID: UUID?

    init() {
        _savedCalls = State(
            initialValue: ContentView.loadInitialCalls()
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($savedCalls) { $call in
                            CallRow(
                                call: $call,
                                isActive:
                                    activeCallID == call.id
                                    && proxyManager.isRunning,
                                onGo: {
                                    startCall(call)
                                },
                                onDelete: {
                                    deleteCall(call)
                                },
                                onChanged: {
                                    saveCalls()
                                }
                            )
                        }

                        HStack {
                            Spacer()

                            Button(action: addCall) {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .frame(
                                        width: 44,
                                        height: 36
                                    )
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                        Divider()
                            .padding(.horizontal)

                        if let captchaURL = proxyManager.captchaURL,
                           let url = URL(string: captchaURL) {
                            CaptchaWebView(url: url)
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: 300,
                                    maxHeight: 500
                                )
                                .padding(.top, 8)
                        }

                        if proxyManager.status == .tunnelConnected {
                            ProxyInfoView(
                                proxyUrl: proxyManager.socksUrl,
                                onCopy: proxyManager.copyProxyUrl
                            )

                            Button(
                                action: {
                                    proxyManager.openHappProxy()
                                }
                            ) {
                                Label(
                                    NSLocalizedString(
                                        "btn_open_in_happ",
                                        comment: ""
                                    ),
                                    systemImage: "globe"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .padding(.horizontal)

                            Button(
                                action: {
                                    proxyManager.openTelegramProxy()
                                }
                            ) {
                                Label(
                                    NSLocalizedString(
                                        "btn_open_in_telegram",
                                        comment: ""
                                    ),
                                    systemImage:
                                        "paperplane.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                }

                if proxyManager.showLogs &&
                    proxyManager.captchaURL == nil {
                    Divider()

                    LogView(logs: proxyManager.logs)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: 260
                        )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarLeading
                ) {
                    StatusIndicator(
                        status: proxyManager.status,
                        errorMessage:
                            proxyManager.errorMessage,
                        statusText:
                            proxyManager.statusText,
                        tunnelMode:
                            proxyManager.tunnelMode
                    )
                }

                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button(
                        action: {
                            showSettings = true
                        }
                    ) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(proxyManager)
            }
            .overlay(alignment: .bottom) {
                if let toast = proxyManager.toastMessage {
                    Text(toast)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(
                            .horizontal,
                            16
                        )
                        .padding(
                            .vertical,
                            10
                        )
                        .background(
                            .ultraThinMaterial
                        )
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .opacity)
                        )
                        .animation(
                            .easeInOut(duration: 0.3),
                            value:
                                proxyManager.toastMessage
                        )
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(
                    UIResponder.resignFirstResponder
                ),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }

    private static func loadInitialCalls() -> [SavedCall] {
        let urls = AppDefaults.savedUrls

        if !urls.isEmpty {
            return urls.map {
                SavedCall(url: $0)
            }
        }

        let legacyUrl = AppDefaults.lastUrl
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if !legacyUrl.isEmpty {
            return [
                SavedCall(url: legacyUrl)
            ]
        }

        return [
            SavedCall()
        ]
    }

    private func saveCalls() {
        AppDefaults.savedUrls = savedCalls.map(\.url)

        let nonEmptyUrls = savedCalls
            .map {
                $0.url.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        AppDefaults.lastUrl =
            nonEmptyUrls.last ?? ""
    }

    private func addCall() {
        savedCalls.append(
            SavedCall()
        )

        saveCalls()
    }

    private func deleteCall(
        _ call: SavedCall
    ) {
        let deletingActive =
            activeCallID == call.id
            && proxyManager.isRunning

        if deletingActive {
            proxyManager.resetAll()
            activeCallID = nil
        }

        savedCalls.removeAll {
            $0.id == call.id
        }

        if savedCalls.isEmpty {
            savedCalls.append(
                SavedCall()
            )
        }

        saveCalls()
    }

    private func startCall(
        _ call: SavedCall
    ) {
        let url = call.url.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !url.isEmpty else {
            return
        }

        if activeCallID == call.id &&
            proxyManager.isRunning {
            proxyManager.resetAll()
            activeCallID = nil
            return
        }

        if proxyManager.isRunning {
            proxyManager.resetAll()
        }

        activeCallID = call.id

        proxyManager.callUrl = url
        proxyManager.connect()

        saveCalls()
    }
}


struct CallRow: View {
    @Binding var call: SavedCall

    let isActive: Bool
    let onGo: () -> Void
    let onDelete: () -> Void
    let onChanged: () -> Void

    private var urlBinding: Binding<String> {
        Binding(
            get: {
                call.url
            },
            set: { newValue in
                call.url = newValue
                onChanged()
            }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onDelete) {
                Image(
                    systemName:
                        "xmark.circle.fill"
                )
                .foregroundColor(.red)
                .font(.title3)
            }
            .frame(
                width: 30,
                height: 36
            )

            TextField(
                NSLocalizedString(
                    "hint_call_link",
                    comment: ""
                ),
                text: urlBinding
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(.URL)

            Button(action: onGo) {
                Text(
                    isActive
                        ? NSLocalizedString(
                            "btn_stop",
                            comment: ""
                        )
                        : NSLocalizedString(
                            "btn_go",
                            comment: ""
                        )
                )
                .fontWeight(.bold)
                .frame(width: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(
                isActive
                    ? .red
                    : .green
            )
        }
        .padding(.horizontal)
    }
}


struct StatusIndicator: View {
    let status: ProxyStatus
    let errorMessage: String
    let statusText: String?
    let tunnelMode: TunnelMode

    var statusColor: Color {
        if statusText != nil {
            return .yellow
        }

        switch status {
        case .idle:
            return .gray
        case .ready:
            return .gray
        case .connecting:
            return .yellow
        case .reconnecting:
            return .yellow
        case .tunnelConnected:
            return .green
        case .tunnelLost:
            return .orange
        case .error:
            return .red
        }
    }

    var displayText: String {
        let statusLabel: String

        if let text = statusText {
            statusLabel = text
        } else if !errorMessage.isEmpty {
            statusLabel = errorMessage
        } else {
            statusLabel = status.displayLabel
        }

        return "\(tunnelMode.label) | \(statusLabel)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(
                    width: 8,
                    height: 8
                )

            Text(displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}


struct ProxyInfoView: View {
    let proxyUrl: String
    let onCopy: () -> Void

    var body: some View {
        HStack {
            Text(proxyUrl)
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )
                .lineLimit(1)
                .truncationMode(.middle)

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(
            Color.green.opacity(0.1)
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }
}


struct LogView: View {
    let logs: [String]

    @State private var userScrolledUp = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 0
                ) {
                    ForEach(
                        logs.indices,
                        id: \.self
                    ) { index in
                        Text(logs[index])
                            .font(
                                .system(
                                    .caption2,
                                    design: .monospaced
                                )
                            )
                            .foregroundColor(
                                .secondary
                            )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(
                Color(.systemGroupedBackground)
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        userScrolledUp = true
                    }
            )
            .onChange(of: logs.count) { _ in
                if !userScrolledUp,
                   let last = logs.indices.last {
                    scrollProxy.scrollTo(
                        last,
                        anchor: .bottom
                    )
                }
            }
        }
    }
}


struct SettingsView: View {
    @EnvironmentObject var proxyManager: ProxyManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(
                    NSLocalizedString(
                        "settings_tunnel",
                        comment: ""
                    )
                ) {
                    Picker(
                        NSLocalizedString(
                            "settings_tunnel_mode",
                            comment: ""
                        ),
                        selection:
                            $proxyManager.tunnelMode
                    ) {
                        Text(
                            NSLocalizedString(
                                "settings_tunnel_dc",
                                comment: ""
                            )
                        )
                        .tag(TunnelMode.dc)

                        Text(
                            NSLocalizedString(
                                "settings_tunnel_video",
                                comment: ""
                            )
                        )
                        .tag(TunnelMode.video)
                    }
                }

                Section(
                    NSLocalizedString(
                        "settings_proxy",
                        comment: ""
                    )
                ) {
                    Picker(
                        NSLocalizedString(
                            "settings_auth_mode",
                            comment: ""
                        ),
                        selection:
                            $proxyManager.socksAuthMode
                    ) {
                        Text(
                            NSLocalizedString(
                                "settings_auth_auto",
                                comment: ""
                            )
                        )
                        .tag(SocksAuthMode.auto)

                        Text(
                            NSLocalizedString(
                                "settings_auth_manual",
                                comment: ""
                            )
                        )
                        .tag(SocksAuthMode.manual)
                    }

                    if proxyManager.socksAuthMode == .manual {
                        TextField(
                            NSLocalizedString(
                                "hint_username",
                                comment: ""
                            ),
                            text:
                                $proxyManager.manualSocksUser
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        TextField(
                            NSLocalizedString(
                                "hint_password",
                                comment: ""
                            ),
                            text:
                                $proxyManager.manualSocksPass
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        HStack {
                            Text("Port")

                            Spacer()

                            TextField(
                                "",
                                value:
                                    $proxyManager.socksPort,
                                format: .number
                            )
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(
                                .trailing
                            )
                            .frame(width: 100)
                        }
                    }
                }

                Section(
                    NSLocalizedString(
                        "settings_display",
                        comment: ""
                    )
                ) {
                    TextField(
                        NSLocalizedString(
                            "hint_display_name",
                            comment: ""
                        ),
                        text:
                            $proxyManager.displayName
                    )

                    Toggle(
                        NSLocalizedString(
                            "settings_show_logs",
                            comment: ""
                        ),
                        isOn:
                            $proxyManager.showLogs
                    )

                    Toggle(
                        NSLocalizedString(
                            "settings_debug",
                            comment: ""
                        ),
                        isOn:
                            $proxyManager.debug
                    )
                }

                Section(
                    NSLocalizedString(
                        "settings_vp8_pacing",
                        comment: ""
                    )
                ) {
                    HStack {
                        Text(
                            NSLocalizedString(
                                "settings_vp8_fps",
                                comment: ""
                            )
                        )

                        Spacer()

                        TextField(
                            "",
                            value:
                                $proxyManager.vp8Fps,
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(width: 80)
                    }

                    HStack {
                        Text(
                            NSLocalizedString(
                                "settings_vp8_batch",
                                comment: ""
                            )
                        )

                        Spacer()

                        TextField(
                            "",
                            value:
                                $proxyManager.vp8Batch,
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(width: 80)
                    }

                    Toggle(
                        isOn:
                            $proxyManager.dualTrack
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(
                                NSLocalizedString(
                                    "vp8_dual_track_title",
                                    comment: ""
                                )
                            )

                            Text(
                                NSLocalizedString(
                                    "vp8_dual_track_sub",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundColor(
                                .secondary
                            )
                        }
                    }

                    Toggle(
                        isOn:
                            $proxyManager.reliable
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(
                                NSLocalizedString(
                                    "vp8_reliable_title",
                                    comment: ""
                                )
                            )

                            Text(
                                NSLocalizedString(
                                    "vp8_reliable_sub",
                                    comment: ""
                                )
                            )
                            .font(.caption)
                            .foregroundColor(
                                .secondary
                            )
                        }
                    }
                }
            }
            .navigationTitle(
                NSLocalizedString(
                    "settings_title",
                    comment: ""
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement:
                        .navigationBarTrailing
                ) {
                    Button(
                        NSLocalizedString(
                            "btn_done",
                            comment: ""
                        )
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }
}