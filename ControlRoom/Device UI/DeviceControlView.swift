//
//  DeviceControlView.swift
//  ControlRoom
//
//  Created by GitHub Copilot on 02/06/2026.
//

import SwiftUI

/// A tabbed control view for physical devices. Similar layout to `ControlView` but
/// with device-specific tabs for system state, apps, and diagnostics.
struct DeviceControlView: View {
    let device: DeviceCtl.Device
    @ObservedObject var devicesController: DevicesController

    var body: some View {
        TabView {
            DeviceDetailView(device: device, devicesController: devicesController)
            DeviceAppView(device: device)
            DeviceDiagnosticsView(device: device)
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
