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

extension DeviceCtl {
    /// The response from `devicectl device info apps --json-output`
    struct ApplicationsList: Decodable {
        let apps: [AppInfo]  // It's an array, not a dictionary!
        
        init(apps: [AppInfo]) {
            self.apps = apps
        }
        
        private enum RootKeys: String, CodingKey { case result }
        private enum ResultKeys: String, CodingKey { case apps }
        
        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: RootKeys.self)
            let result = try root.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
            apps = try result.decode([AppInfo].self, forKey: .apps)
        }
    }
    
    /// Application info as returned by devicectl
    struct AppInfo: Decodable {
        let bundleIdentifier: String
        let name: String
        let url: String
        let version: String?
        let bundleVersion: String?
        let builtByDeveloper: Bool
        let defaultApp: Bool
        let removable: Bool
        
        // Computed property to convert to ApplicationType
        var type: ApplicationType {
            builtByDeveloper ? .user : .system
        }
        
        private enum CodingKeys: String, CodingKey {
            case bundleIdentifier
            case name
            case url
            case version
            case bundleVersion
            case builtByDeveloper
            case defaultApp
            case removable
        }
    }
    
    /// The response from `devicectl device info processes --json-output`
    struct ProcessesList: Decodable {
        let processes: [Process]
        
        init(processes: [Process]) {
            self.processes = processes
        }
        
        private enum RootKeys: String, CodingKey { case result }
        private enum ResultKeys: String, CodingKey { case runningProcesses }
        
        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: RootKeys.self)
            let result = try root.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
            processes = try result.decode([Process].self, forKey: .runningProcesses)
        }
    }
    
    /// Information about a running process on the device
    struct Process: Decodable {
        /// The path to the executable file
        let executable: String
        
        /// The process identifier (PID)
        let processIdentifier: Int
        
        private enum CodingKeys: String, CodingKey {
            case executable
            case processIdentifier
        }
    }
    
    struct ApplicationFilesList: Decodable {
        let appFiles: [AppFile]
        
        init(appFiles: [AppFile]) {
            self.appFiles = appFiles
        }
        
        private enum RootKeys: String, CodingKey { case result }
        private enum ResultKeys: String, CodingKey {
            case appFiles
            case files
        }
        
        init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: RootKeys.self)
            let result = try root.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
            if let decodedFiles = try result.decodeIfPresent([AppFile].self, forKey: .files) {
                appFiles = decodedFiles
            } else {
                appFiles = try result.decode([AppFile].self, forKey: .appFiles)
            }
        }
    }
        
    struct AppFile: Decodable {
        let name: String
        let relativePath: String
        let isDirectory: Bool
        let size: Int?
        let lastModDate: Date?
    
        private enum CodingKeys: String, CodingKey {
            case name
            case relativePath
            case metadata
            case resources
            case isDirectory
            case size
            case lastModDate
        }

        private enum MetadataKeys: String, CodingKey {
            case size
            case lastModDate
        }

        private enum ResourcesKeys: String, CodingKey {
            case isDirectory
        }

        init(name: String, relativePath: String, isDirectory: Bool, size: Int?, lastModDate: Date?) {
            self.name = name
            self.relativePath = relativePath
            self.isDirectory = isDirectory
            self.size = size
            self.lastModDate = lastModDate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let decodedRelativePath = (try? container.decode(String.self, forKey: .relativePath))
                ?? (try? container.decode(String.self, forKey: .name))
                ?? ""
            relativePath = decodedRelativePath

            let decodedName = (try? container.decode(String.self, forKey: .name)) ?? decodedRelativePath
            name = URL(fileURLWithPath: decodedName).lastPathComponent

            if let resources = try? container.nestedContainer(keyedBy: ResourcesKeys.self, forKey: .resources) {
                isDirectory = (try? resources.decode(Bool.self, forKey: .isDirectory)) ?? false
            } else {
                isDirectory = (try? container.decode(Bool.self, forKey: .isDirectory)) ?? false
            }

            let metadata = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata)

            if let decodedSize = try? metadata?.decode(Int.self, forKey: .size) {
                size = decodedSize
            } else if let decodedSize = try? metadata?.decode(String.self, forKey: .size), let parsedSize = Int(decodedSize) {
                size = parsedSize
            } else if let decodedSize = try? container.decode(Int.self, forKey: .size) {
                size = decodedSize
            } else if let decodedSize = try? container.decode(String.self, forKey: .size), let parsedSize = Int(decodedSize) {
                size = parsedSize
            } else {
                size = nil
            }

            if let timestamp = try? metadata?.decode(Double.self, forKey: .lastModDate) {
                lastModDate = Date(timeIntervalSince1970: timestamp)
            } else if let dateString = try? metadata?.decode(String.self, forKey: .lastModDate) {
                lastModDate = Self.date(from: dateString)
            } else if let timestamp = try? container.decode(Double.self, forKey: .lastModDate) {
                lastModDate = Date(timeIntervalSince1970: timestamp)
            } else if let dateString = try? container.decode(String.self, forKey: .lastModDate) {
                lastModDate = Self.date(from: dateString)
            } else {
                lastModDate = nil
            }
        }

        private static func date(from string: String) -> Date? {
            let iso8601WithFractionalSeconds = ISO8601DateFormatter()
            iso8601WithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime]

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

            return iso8601WithFractionalSeconds.date(from: string)
                ?? iso8601.date(from: string)
                ?? formatter.date(from: string)
        }
    }
}

extension DeviceCtl.Process {
    /// Extracts the application container ID from the executable path
    /// e.g., "file:///private/var/containers/Bundle/Application/1D72B91B-67FA-4018-AE03-E1933EEF002F/Calculator.app/Calculator"
    /// returns "1D72B91B-67FA-4018-AE03-E1933EEF002F"
    var appContainerId: String? {
        let path = executable
        guard path.contains("/Application/") else { return nil }
        
        let components = path.components(separatedBy: "/Application/")
        guard components.count > 1 else { return nil }
        
        let afterApplication = components[1]
        let containerId = afterApplication.components(separatedBy: "/").first
        return containerId
    }
}

extension DeviceCtl.AppInfo {
    /// Extracts the application container ID from the app URL
    /// e.g., "file:///private/var/containers/Bundle/Application/1D72B91B-67FA-4018-AE03-E1933EEF002F/Calculator.app/"
    /// returns "1D72B91B-67FA-4018-AE03-E1933EEF002F"
    var appContainerId: String? {
        let path = url
        guard path.contains("/Application/") else { return nil }
        
        let components = path.components(separatedBy: "/Application/")
        guard components.count > 1 else { return nil }
        
        let afterApplication = components[1]
        let containerId = afterApplication.components(separatedBy: "/").first
        return containerId
    }
}


// Keep the old typealias for SimCtl compatibility but reference the new namespace
typealias ApplicationsList = [String: SimCtl.Application]
