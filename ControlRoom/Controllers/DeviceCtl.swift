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

    static func listApplications(_ deviceId: String, includeAllApps: Bool = false) -> AnyPublisher<ApplicationsList, DeviceCtl.Error> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-apps-\(UUID().uuidString).json")
        let flags: [DeviceCtl.Flag] = includeAllApps ? [.jsonOutput(outputURL.path), .includeAllApps] : [.jsonOutput(outputURL.path)]
        let publisher: AnyPublisher<DeviceCtl.DeviceAppsResponse, DeviceCtl.Error> = executeJSONOutput(.listApps(deviceId, flags: flags), outputURL: outputURL)
        return publisher
            .map { response in
                var dict: ApplicationsList = [:]
                response.apps.forEach { app in
                    dict[app.bundleIdentifier] = app
                }
                return dict
            }
            .eraseToAnyPublisher()
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

    static func uninstall(_ deviceId: String, appBundleId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.uninstall(deviceId, appBundleId: appBundleId), completion: completion)
    }

    static func launch(_ deviceId: String, appBundleId: String, options: [Launch.Option] = [], completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.launch(deviceId, appBundleId: appBundleId, options: options), completion: completion)
    }

    static func terminate(_ deviceId: String, appBundleId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.terminate(deviceId, appBundleId: appBundleId), completion: completion)
    }
    
    static func openURL(_ deviceId: String, url: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.openURL(deviceId, url: url), completion: completion)
    }
    
    static func reboot (_ deviceId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.reboot(deviceId), completion: completion)
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
                        promise(.failure(.unknown(error)))
                    }
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .handleEvents(
            receiveCompletion: { _ in try? FileManager.default.removeItem(at: outputURL) },
            receiveCancel: { try? FileManager.default.removeItem(at: outputURL) }
        )
        .tryMap { data -> T in
            return try JSONDecoder().decode(T.self, from: data)
        }
        .mapError { error in
            if let cmd = error as? CommandLineError { return cmd }
            return .unknown(error)
        }
        .eraseToAnyPublisher()
    }
}
