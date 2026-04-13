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
import UniformTypeIdentifiers

/// Presents basic system info for a physical device returned by devicectl.
struct DeviceDetailView: View {
    @EnvironmentObject var deepLinks: DeepLinksController
    @AppStorage("CRApps_LastOpenURL") private var lastOpenURL = ""
    @AppStorage("CRApps_ShowSystemApps") private var shouldShowSystemApps = true
    @State private var installStatusMessage = ""
    @State private var isInstallingApp = false

    let device: DeviceCtl.Device
    @ObservedObject var devicesController: DevicesController

    private var subtitle: String {
        [device.marketingName ?? device.name, device.osVersion.map { "iOS \($0)" }].compactMap { $0 }.joined(separator: " – ")
    }

    var body: some View {
        Form {
            Section {
                labeled("Name", value: device.name)
                labeled("OS Version", value: device.osVersion)
                labeled("Device Model", value: device.marketingName)
                labeled("UDID", value: device.udid)
            } header: {
                Text("Device")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            
            Section {
                labeled("Booted State", value: device.bootState)
                labeled("Paired State", value: device.pairingState)
                labeled("Transport Type", value: device.transportType)
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
                Button("Add App", action: installApp)
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
    }

        

    private func labeled(_ title: String, value: String?) -> some View {
        LabeledContent(title + ":") {
            Text(value ?? "Unknown")
                .textSelection(.enabled)
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
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.ipa, .appBundle]
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
