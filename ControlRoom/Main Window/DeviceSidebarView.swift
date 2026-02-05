//
//  DeviceSidebarView.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import SwiftUI

struct DeviceSidebarView: View {
    let device: DeviceCtl.Device

    private var statusColor: Color {
        switch device.connectionState {
        case .connected:
            return .green
        case .paired:
            return .blue
        case .disconnected:
            return .gray
        default:
            return .gray
        }
    }

    private var platformIconName: String {
        switch device.platform {
        case .iOS?: return "iphone"
        case .tvOS?: return "appletv"
        case .watchOS?: return "applewatch"
        case .visionOS?: return "arkit"
        case .macOS?: return "laptopcomputer"
        default: return "questionmark.circle"
        }
    }

    private var subtitle: String {
        let versionText = device.osVersion.map { "iOS \($0)" }
        let connectionText = connectionStateDescription
        return [versionText, connectionText].compactMap { $0 }.joined(separator: " • ")
    }

    private var connectionStateDescription: String? {
        switch device.connectionState {
        case .connected:
            return "Connected"
        case .paired:
            return "Paired"
        case .disconnected:
            return "Disconnected"
        default:
            return nil
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Image(systemName: platformIconName)
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .lineLimit(1)
                if subtitle.isNotEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeviceSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {

        }
        .previewLayout(.sizeThatFits)
        .padding()
        .frame(width: 240)
    }
}
