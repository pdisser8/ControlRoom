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
            Command(["device", "process", "launch", "--device", deviceId] + options.flatMap(\.arguments) + [appBundleId])
        }
        
        static func terminate(_ deviceId: String, pid: Int, options: [Terminate.Option] = []) -> Command {
            Command(["device", "process", "terminate", "--device", deviceId, "--pid", String(pid)] + options.flatMap(\.arguments))
        }
        
        static func listApps(_ deviceId: String, flags: [Flag] = []) -> Command {
            Command(["device", "info", "apps", "--device", deviceId] + flags.flatMap(\.arguments))
        }

        static func appIcon(_ deviceId: String, appBundleId: String, width: Int, height: Int, scale: Int = 2, allowPlaceholder: Bool = true, destination: String) -> Command {
            Command([
                "device", "info", "appIcon",
                "--device", deviceId,
                "--app-bundle-id", appBundleId,
                "--allow-placeholder", allowPlaceholder ? "true" : "false",
                "--width", String(width),
                "--height", String(height),
                "--scale", String(scale),
                "--destination", destination,
            ])
        }

        static func displays(_ deviceId: String, flags: [Flag] = []) -> Command {
            Command(["device", "info", "displays", "--device", deviceId] + flags.flatMap(\.arguments))
        }

        static func lockState(_ deviceId: String, flags: [Flag] = []) -> Command {
            Command(["device", "info", "lockState", "--device", deviceId] + flags.flatMap(\.arguments))
        }
        
        static func openURL(_ deviceId: String, url: String, appBundleId: String? = nil, options: [Launch.Option] = []) -> Command {
            if let appBundleId, appBundleId.isNotEmpty {
                return launch(deviceId, appBundleId: appBundleId, options: [.payloadURL(url.appLaunchDeepLinkTarget)] + options)
            }

            return Command(["device", "process", "launch", "--device", deviceId, "--payload-url", url, "com.apple.mobilesafari"])
        }
        
        static func reboot (_ deviceId: String) -> Command {
            Command(["device", "reboot", "--device", deviceId])
        }
        
        static func listProcesses(_ deviceId: String, flags: [Flag] = []) -> Command {
            Command(["device", "info", "processes", "--device", deviceId] + flags.flatMap(\.arguments))
        }
        
        static func listApplicationFiles(_ deviceId: String, appBundleId: String, subdirectory: String? = nil, flags: [Flag] = []) -> Command {
            var arguments = ["device", "info", "files", "--device", deviceId, "--domain-type", "appDataContainer", "--domain-identifier", appBundleId]

            if let subdirectory, subdirectory.isNotEmpty {
                arguments += ["--subdirectory", subdirectory]
            }

            return Command(arguments + flags.flatMap(\.arguments))
        }

        static func copyToAppDataContainer(_ deviceId: String, appBundleId: String, sourcePaths: [String], destination: String? = nil, removeExistingContent: Bool = false) -> Command {
            var arguments = ["device", "copy", "to", "--device", deviceId]
            arguments += sourcePaths.flatMap { ["--source", $0] }

            if let destination, destination.isNotEmpty {
                arguments += ["--destination", destination]
            }

            arguments += ["--domain-type", "appDataContainer", "--domain-identifier", appBundleId]
            arguments += ["--remove-existing-content", removeExistingContent ? "true" : "false"]
            return Command(arguments)
        }

        static func copyFromAppDataContainer(_ deviceId: String, appBundleId: String, source: String, destination: String? = nil) -> Command {
            var arguments = ["device", "copy", "from", "--device", deviceId, "--source", source]

            if let destination, destination.isNotEmpty {
                arguments += ["--destination", destination]
            }

            arguments += ["--domain-type", "appDataContainer", "--domain-identifier", appBundleId]
            return Command(arguments)
        }

        static func registerLoggingProfile() -> Command {
            Command(["manage", "loggingProfile", "register"])
        }

        static func sysdiagnose(_ deviceId: String, destination: String? = nil, gatherFullLogs: Bool = false) -> Command {
            var arguments = ["device", "sysdiagnose", "--device", deviceId]

            if let destination, destination.isNotEmpty {
                arguments += ["--destination", destination]
            }

            if gatherFullLogs {
                arguments.append("--gather-full-logs")
            }

            return Command(arguments)
        }

        static func postNotifications(_ deviceId: String, names: [String]) -> Command {
            var arguments = ["device", "notification", "post", "--device", deviceId]
            arguments += names.flatMap { ["--name", $0] }
            return Command(arguments)
        }

        static func observeNotifications(_ deviceId: String, names: [String], sessionTimeout: Int, timeout: Int) -> Command {
            var arguments = ["--timeout", String(timeout), "device", "notification", "observe", "--device", deviceId]
            arguments += names.flatMap { ["--name", $0] }
            arguments += ["--session-timeout", String(sessionTimeout)]
            return Command(arguments)
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
            /// Launches the app in a suspended state, waiting for a debugger to attach
            /// (corresponds to --start-stopped flag)
            case waitForDebugger
            
            /// Environment variables to provide to the process
            /// (corresponds to --environment-variables flag)
            case environment([String: String])
            
            /// The user ID or name to run the process as
            /// (corresponds to --user flag)
            case user(String)
            
            /// The initial working directory for the spawned process
            /// (corresponds to --working-directory flag)
            case workingDirectory(String)
            
            /// A URL to pass to the application for it to open during launch
            /// (corresponds to --payload-url flag)
            case payloadURL(String)
            
            /// Whether to activate the application in the foreground (default: true)
            /// (corresponds to --activate/--no-activate flags)
            case activate(Bool)
            
            /// Terminates any already-running instances of the app prior to launch
            /// (corresponds to --terminate-existing flag)
            case terminateExisting
            
            /// Attaches the application to the console and waits for it to exit
            /// (corresponds to --console flag)
            case console
            
            /// Command-line arguments to pass to the remote application
            case arguments([String])
            
            var arguments: [String] {
                switch self {
                case .waitForDebugger:
                    return ["--start-stopped"]
                case .environment(let env):
                    return env.map { key, value in "--env=\(key)=\(value)" }
                case .user(let user):
                    return ["--user", user]
                case .workingDirectory(let dir):
                    return ["--working-directory", dir]
                case .payloadURL(let url):
                    return ["--payload-url", url]
                case .activate(let shouldActivate):
                    return shouldActivate ? ["--activate"] : ["--no-activate"]
                case .terminateExisting:
                    return ["--terminate-existing"]
                case .console:
                    return ["--console"]
                case .arguments(let args):
                    return args
                }
            }
        }
    }
    
    struct Terminate {
        enum Option {
            /// Use SIGKILL instead of SIGTERM, preventing the target process
            /// from catching the termination signal. This forces immediate termination
            /// without allowing the app to perform cleanup operations.
            case forceKill
            
            var arguments: [String] {
                switch self {
                case .forceKill:
                    return ["--kill"]
                }
            }
        }
    }
}
