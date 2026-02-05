//
//  DeviceDetailView.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.//
//
import SwiftUI
import Combine

/// Presents basic system info for a physical device returned by devicectl.
struct DeviceDetailView: View {
    @EnvironmentObject var deepLinks: DeepLinksController
    @AppStorage("CRApps_LastOpenURL") private var lastOpenURL = ""
    @AppStorage("CRApps_ShowSystemApps") private var shouldShowSystemApps = true

    let device: DeviceCtl.Device

    @State private var applications: [Application] = []
    @State private var allApplications: [Application] = []
    @State private var appsCancellable: AnyCancellable?

    private var subtitle: String {
        [device.marketingName ?? device.name, device.osVersion.map { "iOS \($0)" }].compactMap { $0 }.joined(separator: " – ")
    }

    var body: some View {
        TabView {
            Form {
                Section("Device") {
                    labeled("Name", value: device.name)
                    labeled("Device Model", value: device.marketingName)
                    labeled("UDID", value: device.udid)
                }
                .font(.subheadline)
                
                Spacer()
                Section("System") {
                    labeled("OS Version", value: device.osVersion)
                    labeled("Booted State", value: device.bootState)
                    labeled("Paired State", value: device.pairingState)
                    labeled("Transport Type", value: device.transportType)
                }
                .font(.subheadline)
                Spacer()
                HStack {
                    Button("Pair", action: pairDevice)
                    Button("Unpair", action: unpairDevice)
                    Button("Reboot", action: rebootDevice)
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
            .tabItem { Label("System", systemImage: "gear") }
        }
        .navigationSubtitle(subtitle)
        .onAppear {
            fetchApplications()
        }
        .onChange(of: shouldShowSystemApps) { _ in
            applyFilter()
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

    private func fetchApplications() {
        print("Fetching applications for device \(device.name)...")
        appsCancellable = DeviceCtl.listApplications(device.udid, includeAllApps: true)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch applications: \(error)")
                } else {
                    print("Finished fetching applications for device \(device.name)")
                }
            } receiveValue: { apps in
                let converted = apps.values.compactMap { Application(application: $0) }
                self.allApplications = converted
                applyFilter()
                print("Fetched \(converted.count) applications for device \(device.name)")
            }
    }

    private func applyFilter() {
        if shouldShowSystemApps {
            applications = allApplications
        } else {
            applications = allApplications.filter { $0.type != .system }
        }
    }
}



#if DEBUG
struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailView(device: .preview)
            .frame(width: 480, height: 360)
    }
}
#endif
