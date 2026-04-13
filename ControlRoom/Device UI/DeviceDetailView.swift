//
//  DeviceDetailView.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.//
//
import SwiftUI
import Combine
import AppKit

/// Presents basic system info for a physical device returned by devicectl.
struct DeviceDetailView: View {
    @EnvironmentObject var deepLinks: DeepLinksController
    @AppStorage("CRApps_LastOpenURL") private var lastOpenURL = ""
    @AppStorage("CRApps_ShowSystemApps") private var shouldShowSystemApps = true
    @State private var installStatusMessage = ""
    @State private var isInstallingApp = false
    @State private var displaySummary = "Loading…"
    @State private var lockStateSummary = "Loading…"

    let device: DeviceCtl.Device
    @ObservedObject var devicesController: DevicesController

    private var subtitle: String {
        [device.marketingName ?? device.name, device.osVersion.map { "iOS \($0)" }].compactMap { $0 }.joined(separator: " – ")
    }

    private var developerModeInstructionsURL: URL {
        URL(string: "https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device")!
    }

    var body: some View {
        Form {
            Section {
                labeled("Name", value: device.name)
                labeled("OS Version", value: device.osVersion)
                labeled("Device Model", value: device.marketingName)
                labeled("Display", value: displaySummary)
                labeled("UDID", value: device.udid)
            } header: {
                Text("Device")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            
            Section {
                labeled("Booted State", value: device.bootState)
                labeled("Lock State", value: lockStateSummary)
                labeled("Paired State", value: device.pairingState)
                labeled("Transport Type", value: device.transportType)
                developerModeRow
            } header: {
                Text("State")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            HStack {
                Button("Reboot", action: rebootDevice)
            }
            HStack {
                Button("Install App", action: installApp)
                    .disabled(isInstallingApp)

                if installStatusMessage.isNotEmpty {
                    Text(installStatusMessage)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            HStack {
                Button("Pair", action: pairDevice)
                Button("Unpair", action: unpairDevice)
            }
            HStack {
                TextField("Open URL:", text: $lastOpenURL, prompt: Text("Enter the URL or deep link you want to open"))
                Button("Open", action: openURL)
                Menu("Saved Links") {
                    ForEach(deepLinks.links) { link in
                        Button(link.name) { open(link) }
                    }

                    if deepLinks.links.isEmpty == false {
                        Divider()
                    }

                    Button("Customize…") {
                        UIState.shared.currentSheet = .deepLinkEditor
                    }
                }
                .frame(width: 120)
            }
        }
        .tabItem {
                Text("System")
        }
        .onAppear(perform: loadSupplementalState)
    }

        

    private func labeled(_ title: String, value: String?) -> some View {
        LabeledContent(title + ":") {
            Text(value ?? "Unknown")
                .textSelection(.enabled)
        }
    }

    private var developerModeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Developer Mode:") {
                Text("Check on Device")
                    .foregroundColor(.secondary)
            }

            Text("Most buttons will be inoperable if Developer Mode is off.")
                .font(.caption)
                .foregroundColor(.secondary)

            Link("How to enable Developer Mode", destination: developerModeInstructionsURL)
                .font(.caption)
        }
    }

    /// Opens a URL in the appropriate device app.
    func openURL() {
        DeviceCtl.openURL(device.udid, url: lastOpenURL)
    }
    func open(_ link: DeepLink) {
        DeviceCtl.openURL(device.udid, url: link.url.absoluteString)
    }
    func pairDevice() {
        DeviceCtl.pair(device.udid)
    }
    func unpairDevice() {
        DeviceCtl.unpair(device.udid)
    }
    func rebootDevice() {
        DeviceCtl.reboot(device.udid)
    }

    func installApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Install"
        panel.message = "Choose an .ipa or .app to install on the selected device."

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        let pathExtension = selectedURL.pathExtension.lowercased()
        guard pathExtension == "ipa" || pathExtension == "app" else {
            installStatusMessage = "Choose an .ipa or .app file."
            return
        }

        let preferredBundleIdentifier = inferredBundleIdentifier(from: selectedURL)

        isInstallingApp = true
        installStatusMessage = "Installing \(selectedURL.lastPathComponent)…"

        DeviceCtl.install(device.udid, appBundlePath: selectedURL.path) { result in
            self.isInstallingApp = false

            switch result {
            case .success:
                self.installStatusMessage = "Installed \(selectedURL.lastPathComponent)."
                NotificationCenter.default.post(
                    name: .deviceAppInstallDidFinish,
                    object: self.device.udid,
                    userInfo: [DeviceAppInstallNotification.bundleIdentifierKey: preferredBundleIdentifier as Any]
                )
            case .failure(let error):
                self.installStatusMessage = self.message(for: error)
            }
        }
    }

    private func inferredBundleIdentifier(from url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "app":
            return bundleIdentifierFromAppBundle(at: url)
        case "ipa":
            return bundleIdentifierFromIPA(at: url)
        default:
            return nil
        }
    }

    private func bundleIdentifierFromAppBundle(at url: URL) -> String? {
        let infoPlistURL = url.appendingPathComponent("Info.plist")
        guard
            let plistData = try? Data(contentsOf: infoPlistURL),
            let propertyList = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        else {
            return nil
        }

        return propertyList["CFBundleIdentifier"] as? String
    }

    private func bundleIdentifierFromIPA(at url: URL) -> String? {
        guard let listingData = Process.execute("/usr/bin/unzip", arguments: ["-Z1", url.path]),
              let listing = String(data: listingData, encoding: .utf8)
        else {
            return nil
        }

        guard let infoPlistPath = listing
            .split(separator: "\n")
            .map(String.init)
            .first(where: { $0.hasPrefix("Payload/") && $0.hasSuffix(".app/Info.plist") })
        else {
            return nil
        }

        guard let plistData = Process.execute("/usr/bin/unzip", arguments: ["-p", url.path, infoPlistPath]),
              let propertyList = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        else {
            return nil
        }

        return propertyList["CFBundleIdentifier"] as? String
    }

    private func message(for error: CommandLineError) -> String {
        switch error {
        case .missingCommand:
            return "xcrun could not be launched."
        case .missingOutput:
            return "The install command did not return the expected response."
        case .unknown(let underlyingError):
            let description = underlyingError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return description.isEmpty ? "The app install failed." : description
        }
    }

    private func loadSupplementalState() {
        DeviceCtl.fetchDisplaySummary(device.udid) { result in
            switch result {
            case .success(let summary):
                self.displaySummary = summary
            case .failure:
                self.displaySummary = "Unknown"
            }
        }

        DeviceCtl.fetchLockState(device.udid) { result in
            switch result {
            case .success(let summary):
                self.lockStateSummary = summary
            case .failure:
                self.lockStateSummary = "Unknown"
            }
        }
    }
}

struct DeviceDiagnosticsView: View {
    @State private var loggingProfileStatus = ""
    @State private var sysdiagnoseStatus = ""
    @State private var notificationNames = ""
    @State private var notificationStatus = ""
    @State private var observedNotificationOutput = ""
    @State private var gatherFullLogs = false
    @State private var isRegisteringLoggingProfile = false
    @State private var isGatheringSysdiagnose = false
    @State private var isPostingNotifications = false
    @State private var isObservingNotifications = false

    let device: DeviceCtl.Device

    private var parsedNotificationNames: [String] {
        notificationNames
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter(\.isNotEmpty)
    }

    var body: some View {
        Form {
            Section {
                Text("Register the Core Device logging profile on this Mac so captured system logs include extra detail for debugging and feedback.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                HStack {
                    Button("Register Logging Profile", action: registerLoggingProfile)
                        .disabled(isRegisteringLoggingProfile)

                    if loggingProfileStatus.isNotEmpty {
                        Text(loggingProfileStatus)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Logging Profile")
            }

            Section {
                Toggle("Gather Full Logs", isOn: $gatherFullLogs)

                HStack {
                    Button("Save Sysdiagnose…", action: gatherSysdiagnose)
                        .disabled(isGatheringSysdiagnose)

                    if sysdiagnoseStatus.isNotEmpty {
                        Text(sysdiagnoseStatus)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Sysdiagnose")
            }

            Section {
                TextField("Darwin notifications", text: $notificationNames, prompt: Text("com.example.refresh, com.example.sync"))

                HStack {
                    Button("Post Notifications", action: postNotifications)
                        .disabled(parsedNotificationNames.isEmpty || isPostingNotifications)
                    Button("Observe for 15 Seconds", action: observeNotifications)
                        .disabled(parsedNotificationNames.isEmpty || isObservingNotifications)
                }

                if notificationStatus.isNotEmpty {
                    Text(notificationStatus)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                if observedNotificationOutput.isNotEmpty {
                    Text(observedNotificationOutput)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            } header: {
                Text("Notifications")
            }
        }
        .tabItem {
            Text("Diagnostics")
        }
    }

    private func registerLoggingProfile() {
        isRegisteringLoggingProfile = true
        loggingProfileStatus = "Registering…"

        DeviceCtl.registerLoggingProfile { result in
            self.isRegisteringLoggingProfile = false

            switch result {
            case .success:
                self.loggingProfileStatus = "Registered. Activate it in System Settings."
            case .failure(let error):
                self.loggingProfileStatus = self.message(for: error, fallback: "Logging profile registration failed.")
            }
        }
    }

    private func gatherSysdiagnose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose a folder for the device sysdiagnose."

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        isGatheringSysdiagnose = true
        sysdiagnoseStatus = "Gathering sysdiagnose…"

        DeviceCtl.gatherSysdiagnose(device.udid, destination: destinationURL.path, gatherFullLogs: gatherFullLogs) { result in
            self.isGatheringSysdiagnose = false

            switch result {
            case .success:
                self.sysdiagnoseStatus = "Saved sysdiagnose to \(destinationURL.lastPathComponent)."
            case .failure(let error):
                self.sysdiagnoseStatus = self.message(for: error, fallback: "Sysdiagnose failed.")
            }
        }
    }

    private func postNotifications() {
        isPostingNotifications = true
        notificationStatus = "Posting notifications…"
        observedNotificationOutput = ""

        DeviceCtl.postNotifications(device.udid, names: parsedNotificationNames) { result in
            self.isPostingNotifications = false

            switch result {
            case .success:
                self.notificationStatus = "Posted \(self.parsedNotificationNames.count) notification\(self.parsedNotificationNames.count == 1 ? "" : "s")."
            case .failure(let error):
                self.notificationStatus = self.message(for: error, fallback: "Posting notifications failed.")
            }
        }
    }

    private func observeNotifications() {
        isObservingNotifications = true
        notificationStatus = "Observing notifications for 15 seconds…"
        observedNotificationOutput = ""

        DeviceCtl.observeNotifications(device.udid, names: parsedNotificationNames) { result in
            self.isObservingNotifications = false

            switch result {
            case .success(let output):
                self.notificationStatus = "Observation finished."
                self.observedNotificationOutput = output.isEmpty ? "No notifications were observed." : output
            case .failure(let error):
                self.notificationStatus = self.message(for: error, fallback: "Observing notifications failed.")
            }
        }
    }

    private func message(for error: CommandLineError, fallback: String) -> String {
        switch error {
        case .missingCommand:
            return "xcrun could not be launched."
        case .missingOutput:
            return "The command did not return the expected response."
        case .unknown(let underlyingError):
            let description = underlyingError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return description.isEmpty ? fallback : description
        }
    }

}

extension Notification.Name {
    static let deviceAppInstallDidFinish = Notification.Name("deviceAppInstallDidFinish")
}

enum DeviceAppInstallNotification {
    static let bundleIdentifierKey = "bundleIdentifier"
}



#if DEBUG
struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailView(device: .preview, devicesController: DevicesController())
            .frame(width: 480, height: 360)
    }
}
#endif
