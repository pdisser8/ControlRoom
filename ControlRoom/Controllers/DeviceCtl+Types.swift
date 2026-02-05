//
//  DeviceCtl+Types.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import Foundation

extension DeviceCtl {
    enum Platform: String, CaseIterable, Codable {
        case iOS = "ios"
        case tvOS = "tvos"
        case watchOS = "watchos"
        case visionOS = "visionos"
        case macOS = "macos"
        case unknown
    }

    struct DeviceList: Decodable, Equatable {
        let devices: [Device]

        private enum RootKeys: String, CodingKey { case result }
        private enum ResultKeys: String, CodingKey { case devices }

        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: RootKeys.self)
            let result = try root.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
            devices = try result.decode([Device].self, forKey: .devices)
        }
    }

    struct Device: Decodable, Equatable, Identifiable {
        let udid: String
        let name: String
        let platform: Platform?
        let osVersion: String?
        let marketingName: String?
        let bootState: String?
        let pairingState: String?
        let transportType: String?
        let connectionState: ConnectionState?
        let isPaired: Bool?
        let isConnected: Bool?
        let connectionType: String?

        var id: String { udid }

        init(udid: String,
             name: String,
             platform: Platform?,
             osVersion: String?,
             marketingName: String?,
             bootState: String?,
             pairingState: String?,
             transportType: String?,
             connectionState: ConnectionState?,
             isPaired: Bool?,
             isConnected: Bool?,
             connectionType: String?) {
            self.udid = udid
            self.name = name
            self.platform = platform
            self.osVersion = osVersion
            self.marketingName = marketingName
            self.bootState = bootState
            self.pairingState = pairingState
            self.transportType = transportType
            self.connectionState = connectionState
            self.isPaired = isPaired
            self.isConnected = isConnected
            self.connectionType = connectionType
        }

        private enum CodingKeys: String, CodingKey {
            case identifier
            case hardwareProperties
            case deviceProperties
            case connectionProperties
        }

        private enum HardwareKeys: String, CodingKey { case udid, platform, marketingName }
        private enum DevicePropsKeys: String, CodingKey { case name, osVersionNumber, bootState }
        private enum ConnectionPropsKeys: String, CodingKey { case pairingState, tunnelState, transportType }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let hardware = try container.nestedContainer(keyedBy: HardwareKeys.self, forKey: .hardwareProperties)
            udid = try hardware.decode(String.self, forKey: .udid)
            let platformString = try? hardware.decode(String.self, forKey: .platform)
            platform = platformString.flatMap { Platform(rawValue: $0.lowercased()) }
            marketingName = try? hardware.decode(String.self, forKey: .marketingName)

            let deviceProps = try container.nestedContainer(keyedBy: DevicePropsKeys.self, forKey: .deviceProperties)
            name = (try? deviceProps.decode(String.self, forKey: .name)) ?? "Unknown"
            osVersion = try? deviceProps.decode(String.self, forKey: .osVersionNumber)
            bootState = try? deviceProps.decode(String.self, forKey: .bootState)

            if let connectionProps = try? container.nestedContainer(keyedBy: ConnectionPropsKeys.self, forKey: .connectionProperties) {
                pairingState = try? connectionProps.decode(String.self, forKey: .pairingState)
                let tunnelState = try? connectionProps.decode(String.self, forKey: .tunnelState)
                transportType = try? connectionProps.decode(String.self, forKey: .transportType)
                connectionType = transportType

                if tunnelState?.lowercased() == "connected" {
                    connectionState = .connected
                    isConnected = true
                } else if pairingState?.lowercased() == "paired" {
                    connectionState = .paired
                    isConnected = false
                } else {
                    connectionState = .disconnected
                    isConnected = false
                }
                isPaired = pairingState?.lowercased() == "paired"
            } else {
                pairingState = nil
                transportType = nil
                connectionType = nil
                connectionState = .unknown
                isPaired = nil
                isConnected = nil
            }
        }
    }

    enum ConnectionState: String, Decodable {
        case connected
        case disconnected
        case paired
        case unknown
    }

    struct RuntimeList: Decodable, Equatable {
        let runtimes: [Runtime]
    }

    struct Runtime: Decodable, Equatable, Identifiable {
        let identifier: String
        let name: String
        let version: String
        let isAvailable: Bool?

        var id: String { identifier }
    }

    typealias ApplicationsList = [String: DeviceCtl.Application]

    struct Application: Decodable, Equatable, Identifiable {
        let bundleIdentifier: String
        let displayName: String
        let bundlePath: String
        let version: String?
        let bundleVersion: String?
        let appClip: Bool?
        let builtByDeveloper: Bool?
        let defaultApp: Bool?
        let hidden: Bool?
        let internalApp: Bool?
        let removable: Bool?
        let executablePath: String?
        let containerPath: String?
        
        var id: String { bundleIdentifier }

        private enum CodingKeys: String, CodingKey {
            // Current devicectl (jsonVersion 2)
            case bundleIdentifier
            case name
            case url
            case version
            case bundleVersion
            case appClip
            case builtByDeveloper
            case defaultApp
            case hidden
            case internalApp
            case removable
            case executablePath
            case containerPath
            // Legacy simulator output (jsonVersion 1)
            case cfBundleIdentifier = "CFBundleIdentifier"
            case cfBundleDisplayName = "CFBundleDisplayName"
            case bundle = "Bundle"
            case executable = "Executable"
            case container = "Container"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
                ?? container.decode(String.self, forKey: .cfBundleIdentifier)

            displayName = try container.decodeIfPresent(String.self, forKey: .name)
                ?? container.decodeIfPresent(String.self, forKey: .cfBundleDisplayName)
                ?? bundleIdentifier

            bundlePath = try container.decodeIfPresent(String.self, forKey: .url)
                ?? container.decodeIfPresent(String.self, forKey: .bundle)
                ?? ""

            version = try? container.decode(String.self, forKey: .version)
            bundleVersion = try? container.decode(String.self, forKey: .bundleVersion)
            appClip = try? container.decode(Bool.self, forKey: .appClip)
            builtByDeveloper = try? container.decode(Bool.self, forKey: .builtByDeveloper)
            defaultApp = try? container.decode(Bool.self, forKey: .defaultApp)
            hidden = try? container.decode(Bool.self, forKey: .hidden)
            internalApp = try? container.decode(Bool.self, forKey: .internalApp)
            removable = try? container.decode(Bool.self, forKey: .removable)

            executablePath = try container.decodeIfPresent(String.self, forKey: .executablePath)
                ?? container.decodeIfPresent(String.self, forKey: .executable)
            containerPath = try container.decodeIfPresent(String.self, forKey: .containerPath)
                ?? container.decodeIfPresent(String.self, forKey: .container)
        }
    }

    // MARK: - DeviceAppsResponse

    struct DeviceAppsResponse: Decodable, Equatable {
        let apps: [Application]

        private enum RootKeys: String, CodingKey { case result }
        private enum ResultKeys: String, CodingKey { case apps }

        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: RootKeys.self)
            let result = try root.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
            apps = try result.decode([Application].self, forKey: .apps)
        }
    }
}

extension DeviceCtl.Device {
    static let preview = DeviceCtl.Device(
        udid: "0000-1111",
        name: "Sample iPhone",
        platform: .iOS,
        osVersion: "18.5",
        marketingName: "iPhone 15",
        bootState: "booted",
        pairingState: "paired",
        transportType: "wired",
        connectionState: .connected,
        isPaired: true,
        isConnected: true,
        connectionType: "wired"
    )
}

// Allow unqualified references to DeviceAppsResponse elsewhere in the codebase
typealias DeviceAppsResponse = DeviceCtl.DeviceAppsResponse
