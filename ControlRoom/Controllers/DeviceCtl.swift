//
//  DeviceCtl.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import Combine
import Foundation

/// A container for interacting with `xcrun devicectl`.
enum DeviceCtl: CommandLineCommandExecuter {
    typealias Error = CommandLineError

    static let launchPath = "/usr/bin/xcrun"

    static func watchDeviceList(filter: DeviceFilter? = nil) -> AnyPublisher<DeviceList, DeviceCtl.Error> {
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .setFailureType(to: DeviceCtl.Error.self)
            .flatMap { _ in return DeviceCtl.listDevices(filter: filter) }
            .prepend(DeviceCtl.listDevices(filter: filter))
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    static func listDevices(filter: DeviceFilter? = nil) -> AnyPublisher<DeviceList, DeviceCtl.Error> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-devices-\(UUID().uuidString).json")
        return executeJSONOutput(.list(.devices(filter), flags: [.jsonOutput(outputURL.path)]), outputURL: outputURL)
    }

    static func listApplications(_ deviceId: String, includeAllApps: Bool = true) -> AnyPublisher<DeviceCtl.ApplicationsList, DeviceCtl.Error> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-apps-\(UUID().uuidString).json")
        var flags: [Flag] = [.jsonOutput(outputURL.path)]
        if includeAllApps {
            flags.append(.includeAllApps)
        }
        return executeJSONOutput(.listApps(deviceId, flags: flags), outputURL: outputURL)
    }

    static func deviceInfo(_ deviceId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.deviceInfo(deviceId), completion: completion)
    }

    static func pair(_ deviceId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.pair(deviceId), completion: completion)
    }

    static func unpair(_ deviceId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.unpair(deviceId), completion: completion)
    }

    static func install(_ deviceId: String, appBundlePath: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.install(deviceId, appBundle: appBundlePath), completion: completion)
    }

    static func uninstall(_ deviceId: String, appID: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.uninstall(deviceId, appBundleId: appID), completion: completion)
    }

    static func launch(_ deviceId: String, appID: String, options: [Launch.Option] = [], completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.launch(deviceId, appBundleId: appID, options: options), completion: completion)
    }

    static func terminate(_ deviceId: String, pid: Int, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.terminate(deviceId, pid: pid), completion: completion)
    }
    
    static func openURL(_ deviceId: String, url: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.openURL(deviceId, url: url), completion: completion)
    }
    
    static func reboot (_ deviceId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.reboot(deviceId), completion: completion)
    }
    
    static func listProcesses(_ deviceId: String) -> AnyPublisher<DeviceCtl.ProcessesList, DeviceCtl.Error> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-processes-\(UUID().uuidString).json")
        return executeJSONOutput(.listProcesses(deviceId, flags: [.jsonOutput(outputURL.path)]), outputURL: outputURL)
    }
    
    /// Finds the PID of a running app by matching bundle identifier to process executable path
    static func findPid(for bundleId: String, on deviceId: String) -> AnyPublisher<Int?, DeviceCtl.Error> {
        Publishers.Zip(
            listApplications(deviceId, includeAllApps: true),
            listProcesses(deviceId)
        )
        .map { (appsList, processesList) -> Int? in
            // Find the app with matching bundle identifier
            guard let app = appsList.apps.first(where: { $0.bundleIdentifier == bundleId }) else {
                return nil
            }
            
            // Find the process with matching container ID
            guard let appContainerId = app.appContainerId else {
                return nil
            }
            
            let matchingProcess = processesList.processes.first { process in
                process.appContainerId == appContainerId
            }
            
            return matchingProcess?.processIdentifier
        }
        .eraseToAnyPublisher()
    }
    
    static func listApplicationFiles(_ deviceId: String, appBundleId: String) -> AnyPublisher<DeviceCtl.ApplicationFilesList, DeviceCtl.Error> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-appfiles-\(UUID().uuidString).json")
        return executeJSONOutput(.listApplicationFiles(deviceId, appBundleId: appBundleId, flags: [.jsonOutput(outputURL.path)]), outputURL: outputURL)
    }

    private static func executeJSONOutput<T: Decodable>(_ command: Command, outputURL: URL) -> AnyPublisher<T, DeviceCtl.Error> {
        Future<Data, DeviceCtl.Error> { promise in
            execute(command) { result in
                switch result {
                case .success:
                    do {
                        let data = try Data(contentsOf: outputURL)
                        promise(.success(data))
                    } catch {
                        print("❌ Failed to read JSON file: \(error)")
                        promise(.failure(.unknown(error)))
                    }
                case .failure(let error):
                    print("❌ Command execution failed: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .handleEvents(
            receiveCompletion: { _ in try? FileManager.default.removeItem(at: outputURL) },
            receiveCancel: { try? FileManager.default.removeItem(at: outputURL) }
        )
        .tryMap { data -> T in
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("❌ JSON decode error: \(error)")
                throw error
            }
        }
        .mapError { error in
            if let cmd = error as? CommandLineError { return cmd }
            return .unknown(error)
        }
        .eraseToAnyPublisher()
    }
}
