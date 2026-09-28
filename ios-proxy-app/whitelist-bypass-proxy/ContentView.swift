import SwiftUI
import UIKit

struct SavedCall: Identifiable {
    let id: UUID
    var url: String

    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }
}

struct ContentView: View {
    @EnvironmentObject var proxyManager: ProxyManager

    @State private var savedCalls: [SavedCall]
    @State private var showSettings = false
    @State private var activeCallID: UUID?
    @State private var shareLogItem: LogShareItem?

    init() {
        _savedCalls = State(initialValue: Self.loadInitialCalls())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {

                    // Saved call rows
                    ForEach($savedCalls) { $call in
                        CallRow(
                            call: $call,
                            isActive: activeCallID == call.id &&
                                proxyManager.isRunning,
                            onChanged: {
                                if activeCallID == call.id {
                                    proxyManager.callUrl = call.url
                                }

                                saveCalls()
                            },
                            onGo: {
                                startCall(call)
                            },
                            onDelete: {
                                deleteCall(call)
                            }
                        )
                    }

                    // Add
                    Button {
                        addCall()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                    }
                    .buttonStyle(.bordered)

                    // The only divider in the main screen.
                    Divider()

                    // Captcha
                    if let captchaURL = proxyManager.captchaURL,
                       let url = URL(string: captchaURL) {
                        CaptchaWebView(url: url)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 300,
                                maxHeight: 500
                            )
                    }

                    // Connected proxy information and actions.
                    if proxyManager.status == .tunnelConnected {
                        ProxyInfoView(
                            proxyUrl: proxyManager.socksUrl,
                            onCopy: proxyManager.copyProxyUrl
                        )

                        Button(action: {
                            proxyManager.openHappProxy()
                        }) {
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

                        Button(action: {
                            proxyManager.openTelegramProxy()
                        }) {
                            Label(
                                NSLocalizedString(
                                    "btn_open_in_telegram",
                                    comment: ""
                                ),
                                systemImage: "paperplane.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .padding(.horizontal)
                    }

                    // Logs
                    if proxyManager.showLogs &&
                        proxyManager.captchaURL == nil {
                        LogView(logs: proxyManager.logs)
                    }
                    if proxyManager.showLogs &&
                        proxyManager.captchaURL == nil {

                        LogView(logs: proxyManager.logs)

                        if !proxyManager.logs.isEmpty {
                            HStack {
                                Spacer()

                                Button {
                                    guard let url = proxyManager.makeLogFile() else {
                                        return
                                    }

                                    shareLogItem = LogShareItem(url: url)
                                } label: {
                                    Label(
                                        "Поделиться логом",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Spacer()
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    StatusIndicator(
                        status: proxyManager.status,
                        errorMessage: proxyManager.errorMessage,
                        statusText: proxyManager.statusText,
                        tunnelMode: proxyManager.tunnelMode
                    )
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(proxyManager)
            }
            .sheet(item: $shareLogItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .overlay(alignment: .bottom) {
                if let toast = proxyManager.toastMessage {
                    Text(toast)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .opacity)
                        )
                        .animation(
                            .easeInOut(duration: 0.3),
                            value: proxyManager.toastMessage
                        )
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }

    private static func loadInitialCalls() -> [SavedCall] {
        let urls = AppDefaults.savedUrls

        if !urls.isEmpty {
            return urls.map { SavedCall(url: $0) }
        }

        // Backward compatibility with older versions.
        if !AppDefaults.lastUrl.isEmpty {
            return [SavedCall(url: AppDefaults.lastUrl)]
        }

        return []
    }

    private func saveCalls() {
        let urls = savedCalls
            .map {
                $0.url.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }

        AppDefaults.savedUrls = urls

        // Keep legacy lastUrl synchronized.
        // Important: clear it when the list becomes empty,
        // otherwise a deleted URL could reappear on next launch.
        AppDefaults.lastUrl = urls.first ?? ""
    }

    private func addCall() {
        savedCalls.append(
            SavedCall(url: "")
        )
    }

    private func deleteCall(_ call: SavedCall) {
        if activeCallID == call.id &&
            proxyManager.isRunning {
            proxyManager.resetAll()
            activeCallID = nil
        }

        savedCalls.removeAll {
            $0.id == call.id
        }

        saveCalls()
    }

    private func startCall(_ call: SavedCall) {
        let url = call.url.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !url.isEmpty else {
            proxyManager.showToast(
                NSLocalizedString(
                    "hint_call_link",
                    comment: ""
                )
            )
            return
        }

        // Pressing GO on the active row acts as STOP.
        if activeCallID == call.id &&
            proxyManager.isRunning {
            proxyManager.resetAll()
            activeCallID = nil
            return
        }

        // Only one tunnel may be active at a time.
        if proxyManager.isRunning {
            proxyManager.resetAll()
            activeCallID = nil
        }

        proxyManager.callUrl = url
        proxyManager.connect()

        if proxyManager.isRunning {
            activeCallID = call.id
        } else {
            activeCallID = nil
        }
    }
}

struct CallRow: View {
    @Binding var call: SavedCall

    let isActive: Bool
    let onChanged: () -> Void
    let onGo: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {

            // Delete button is intentionally first.
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(
                        width: 28,
                        height: 36
                    )
            }
            .buttonStyle(.plain)

            ZStack(alignment: .trailing) {
                TextField(
                    NSLocalizedString(
                        "hint_call_link",
                        comment: ""
                    ),
                    text: $call.url
                )
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .padding(
                    .trailing,
                    call.url.isEmpty ? 0 : 24
                )
                .onChange(of: call.url) { _ in
                    onChanged()
                }

                if !call.url.isEmpty {
                    Button {
                        call.url = ""
                        onChanged()
                    } label: {
                        Image(
                            systemName: "xmark.circle.fill"
                        )
                        .foregroundColor(.gray)
                    }
                    .padding(.trailing, 6)
                }
            }

            Button {
                onGo()
            } label: {
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
                .frame(width: 60)
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
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(
                Color(.systemGroupedBackground)
            )
            .simultaneousGesture(
                DragGesture().onChanged { _ in
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
                        selection: $proxyManager.tunnelMode
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
                        selection: $proxyManager.socksAuthMode
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
                            text: $proxyManager.manualSocksUser
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        TextField(
                            NSLocalizedString(
                                "hint_password",
                                comment: ""
                            ),
                            text: $proxyManager.manualSocksPass
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        HStack {
                            Text("Port")

                            Spacer()

                            TextField(
                                "",
                                value: $proxyManager.socksPort,
                                format: .number
                            )
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
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
                        text: $proxyManager.displayName
                    )

                    Toggle(
                        NSLocalizedString(
                            "settings_show_logs",
                            comment: ""
                        ),
                        isOn: $proxyManager.showLogs
                    )

                    Toggle(
                        NSLocalizedString(
                            "settings_debug",
                            comment: ""
                        ),
                        isOn: $proxyManager.debug
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
                            value: $proxyManager.vp8Fps,
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
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
                            value: $proxyManager.vp8Batch,
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    }

                    Toggle(
                        isOn: $proxyManager.dualTrack
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
                            .foregroundColor(.secondary)
                        }
                    }

                    Toggle(
                        isOn: $proxyManager.reliable
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
                            .foregroundColor(.secondary)
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
                    placement: .navigationBarTrailing
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

private struct LogShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}