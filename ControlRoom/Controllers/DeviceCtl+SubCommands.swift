//
//  DeviceCtl+SubCommands.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import Foundation

extension DeviceCtl {
    struct Command: CommandLineCommand {
        let arguments: [String]
        let environmentOverrides: [String: String]?

        private init(_ components: [String], arguments: [String] = [], environmentOverrides: [String: String]? = nil) {
            self.arguments = ["devicectl"] + components + arguments
            self.environmentOverrides = environmentOverrides
        }

        static func list(_ scope: List, flags: [Flag] = []) -> Command {
            Command(scope.arguments + flags.flatMap(\.arguments))
        }

        static func deviceInfo(_ deviceId: String) -> Command {
            Command(["device", "info", deviceId])
        }

        static func pair(_ deviceId: String) -> Command {
            Command(["manage", "pair", "--device", deviceId])
        }

        static func unpair(_ deviceId: String) -> Command {
            Command(["manage", "unpair", "--device", deviceId])
        }

        static func install(_ deviceId: String, appBundle: String) -> Command {
            Command(["device", "install", "app", "--device", deviceId, appBundle])
        }

        static func uninstall(_ deviceId: String, appBundleId: String) -> Command {
            Command(["device", "uninstall", "app", "--device", deviceId, appBundleId])
        }

        static func launch(_ deviceId: String, appBundleId: String, options: [Launch.Option] = []) -> Command {
            Command(["device", "process", "launch"] + options.flatMap(\.arguments) + [deviceId, appBundleId])
        }

        static func terminate(_ deviceId: String, appBundleId: String) -> Command {
            Command(["device", "process", "terminate", "--device", deviceId, "--app", appBundleId])
        }

        static func listApps(_ deviceId: String, flags: [Flag] = []) -> Command {
            Command(["device", "info", "apps", "--device", deviceId] + flags.flatMap(\.arguments))
        }
        
        static func openURL(_ deviceId: String, url: String) -> Command {
            Command(["device", "process", "launch", "--device", deviceId, "--payload-url", url, "com.apple.mobilesafari"])
        }
        
        static func reboot (_ deviceId: String) -> Command {
            Command(["device", "reboot", "--device", deviceId])
        }
    }

    enum List {
        case devices(DeviceFilter? = nil)
        case preferredDDI

        var arguments: [String] {
            switch self {
            case .devices(let filter):
                return ["list", "devices"] + (filter?.arguments ?? [])
            case .preferredDDI:
                return ["list", "preferred-ddi"]
            }
        }
    }

    enum Flag: Hashable {
        case json
        case verbose
        case jsonOutput(String)
        case includeAllApps

        var arguments: [String] {
            switch self {
            case .json:
                return ["--json"]
            case .verbose:
                return ["--verbose"]
            case .jsonOutput(let path):
                return ["--json-output", path]
            case .includeAllApps:
                return ["--include-all-apps"]
            }
        }
    }

    enum DeviceFilter {
        case availableOnly
        case platform(Platform)
        case name(String)
        case udid(String)

        var arguments: [String] {
            switch self {
            case .availableOnly:
                return ["--available"]
            case .platform(let platform):
                return ["--platform", platform.rawValue]
            case .name(let name):
                return ["--name", name]
            case .udid(let udid):
                return ["--udid", udid]
            }
        }
    }

    struct Launch {
        enum Option {
            case waitForDebugger
            case environment([String: String])

            var arguments: [String] {
                switch self {
                case .waitForDebugger:
                    return ["--wait-for-debugger"]
                case .environment(let env):
                    return env.map { key, value in "--env=\(key)=\(value)" }
                }
            }
        }
    }
}
