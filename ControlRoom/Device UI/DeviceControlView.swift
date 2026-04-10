//
//  DeviceControlView.swift
//  ControlRoom
//
//  Created by GitHub Copilot on 02/06/2026.
//

import SwiftUI

/// A tabbed control view for physical devices. Similar layout to `ControlView` but
/// with device-specific tabs (System + Apps). Uses `DevicesController` for apps data.
struct DeviceControlView: View {
    let device: DeviceCtl.Device
    @ObservedObject var devicesController: DevicesController

    var body: some View {
        TabView {
            // System tab reuses the DeviceDetailView content
            DeviceDetailView(device: device, devicesController: devicesController)
            // Apps tab loads apps itself using DeviceCtl
            DeviceAppView(device: device)
        }
        .navigationSubtitle([device.marketingName ?? device.name, device.osVersion.map { "iOS \($0)" }].compactMap { $0 }.joined(separator: " – "))
    }
}


#if DEBUG
struct DeviceControlView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceControlView(device: .preview, devicesController: DevicesController())
            .frame(width: 700, height: 400)
    }
}
#endif
