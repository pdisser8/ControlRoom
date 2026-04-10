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
}



#if DEBUG
struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailView(device: .preview, devicesController: DevicesController())
            .frame(width: 480, height: 360)
    }
}
#endif
