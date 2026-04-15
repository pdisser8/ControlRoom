//
//  DeviceCtl.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import Combine
import Foundation
import AppKit

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

    static func fetchAppIcon(_ deviceId: String, appBundleId: String, width: Int = 60, height: Int = 60, scale: Int = 2, allowPlaceholder: Bool = true, completion: @escaping (NSImage?) -> Void) {
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-appicon-\(UUID().uuidString).png")

        execute(.appIcon(deviceId, appBundleId: appBundleId, width: width, height: height, scale: scale, allowPlaceholder: allowPlaceholder, destination: destinationURL.path)) { result in
            defer {
                try? FileManager.default.removeItem(at: destinationURL)
            }

            guard case .success = result,
                  let image = NSImage(contentsOf: destinationURL)
            else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
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
    
    static func openURL(_ deviceId: String, url: String, appID: String? = nil, options: [Launch.Option] = [], completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.openURL(deviceId, url: url, appBundleId: appID, options: options), completion: completion)
    }
    
    static func reboot (_ deviceId: String, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.reboot(deviceId), completion: completion)
    }

    static func fetchDisplaySummary(_ deviceId: String, completion: @escaping (Result<String, DeviceCtl.Error>) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-displays-\(UUID().uuidString).json")
        executeJSONValueOutput(.displays(deviceId, flags: [.jsonOutput(outputURL.path)]), outputURL: outputURL) { result in
            switch result {
            case .success(let json):
                completion(.success(parseDisplaySummary(from: json) ?? "Unknown"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func fetchLockState(_ deviceId: String, completion: @escaping (Result<String, DeviceCtl.Error>) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-lockstate-\(UUID().uuidString).json")
        executeJSONValueOutput(.lockState(deviceId, flags: [.jsonOutput(outputURL.path)]), outputURL: outputURL) { result in
            switch result {
            case .success(let json):
                completion(.success(parseLockState(from: json) ?? "Unknown"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func registerLoggingProfile(completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.registerLoggingProfile(), completion: completion)
    }

    static func gatherSysdiagnose(_ deviceId: String, destination: String, gatherFullLogs: Bool = false, completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.sysdiagnose(deviceId, destination: destination, gatherFullLogs: gatherFullLogs), completion: completion)
    }

    static func postNotifications(_ deviceId: String, names: [String], completion: ((Result<Data, CommandLineError>) -> Void)? = nil) {
        execute(.postNotifications(deviceId, names: names), completion: completion)
    }

    static func observeNotifications(_ deviceId: String, names: [String], sessionTimeout: Int = 15, timeout: Int = 20, completion: @escaping (Result<String, DeviceCtl.Error>) -> Void) {
        executeText(.observeNotifications(deviceId, names: names, sessionTimeout: sessionTimeout, timeout: timeout)) { result in
            switch result {
            case .success(let output):
                completion(.success(output.trimmingCharacters(in: .whitespacesAndNewlines)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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

    static func listApplicationFiles(_ deviceId: String, appBundleId: String, subdirectory: String) -> AnyPublisher<DeviceCtl.ApplicationFilesList, DeviceCtl.Error> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("devicectl-appfiles-\(UUID().uuidString).json")
        return executeJSONOutput(.listApplicationFiles(deviceId, appBundleId: appBundleId, subdirectory: subdirectory, flags: [.jsonOutput(outputURL.path)]), outputURL: outputURL)
    }

    static func copyItemsToApplicationContainer(_ deviceId: String, appBundleId: String, sourceURLs: [URL], destinationPath: String, removeExistingContent: Bool = false, completion: ((Result<Data, DeviceCtl.Error>) -> Void)? = nil) {
        let normalizedDestination = normalizeRemotePath(destinationPath)

        DispatchQueue.global(qos: .userInitiated).async {
            for sourceURL in sourceURLs {
                let explicitDestination = explicitRemoteDestination(basePath: normalizedDestination, sourceURL: sourceURL)

                switch runFileCommand(.copyToAppDataContainer(deviceId, appBundleId: appBundleId, sourcePaths: [sourceURL.path], destination: explicitDestination, removeExistingContent: removeExistingContent)) {
                case .success:
                    continue
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion?(.failure(error))
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                completion?(.success(Data()))
            }
        }
    }

    static func copyItemsFromApplicationContainer(_ deviceId: String, appBundleId: String, sourcePaths: [String], destinationDirectory: URL, completion: ((Result<Data, DeviceCtl.Error>) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            for sourcePath in sourcePaths {
                let sourceName = URL(fileURLWithPath: sourcePath).lastPathComponent
                let destinationURL = destinationDirectory.appendingPathComponent(sourceName, isDirectory: false)

                switch runFileCommand(.copyFromAppDataContainer(deviceId, appBundleId: appBundleId, source: sourcePath, destination: destinationURL.path)) {
                case .success:
                    continue
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion?(.failure(error))
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                completion?(.success(Data()))
            }
        }
    }

    static func deleteItemsFromApplicationContainer(_ deviceId: String, appBundleId: String, itemNames: [String], inDirectory directory: String, completion: ((Result<Data, DeviceCtl.Error>) -> Void)? = nil) {
        let namesToDelete = Set(itemNames)
        guard namesToDelete.isNotEmpty else {
            completion?(.success(Data()))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let workingDirectory = fileManager.temporaryDirectory.appendingPathComponent("devicectl-delete-\(UUID().uuidString)", isDirectory: true)
            let snapshotDirectory = workingDirectory.appendingPathComponent("snapshot", isDirectory: true)
            let remoteDirectory = normalizeRemotePath(directory)
            let remoteSource = remoteDirectory ?? "."

            do {
                try fileManager.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
            } catch {
                DispatchQueue.main.async {
                    completion?(.failure(.unknown(error)))
                }
                return
            }

            defer {
                try? fileManager.removeItem(at: workingDirectory)
            }

            switch runFileCommand(.copyFromAppDataContainer(deviceId, appBundleId: appBundleId, source: remoteSource, destination: snapshotDirectory.path)) {
            case .success:
                break
            case .failure(let error):
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
                return
            }

            let localDirectory = materializedDirectory(in: snapshotDirectory, remoteDirectory: remoteDirectory)

            for itemName in namesToDelete {
                let localItem = localDirectory.appendingPathComponent(itemName)
                if fileManager.fileExists(atPath: localItem.path) {
                    try? fileManager.removeItem(at: localItem)
                }
            }

            let syncSource = localDirectory.appendingPathComponent(".")
            let result = runFileCommand(.copyToAppDataContainer(deviceId, appBundleId: appBundleId, sourcePaths: [syncSource.path], destination: remoteDirectory, removeExistingContent: true))

            DispatchQueue.main.async {
                completion?(result)
            }
        }
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

    private static func executeJSONValueOutput(_ command: Command, outputURL: URL, completion: @escaping (Result<Any, DeviceCtl.Error>) -> Void) {
        execute(command) { result in
            defer {
                try? FileManager.default.removeItem(at: outputURL)
            }

            switch result {
            case .success:
                do {
                    let data = try Data(contentsOf: outputURL)
                    let json = try JSONSerialization.jsonObject(with: data)
                    completion(.success(json))
                } catch {
                    completion(.failure(.unknown(error)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func executeText(_ command: Command, completion: @escaping (Result<String, DeviceCtl.Error>) -> Void) {
        execute(command) { result in
            switch result {
            case .success(let data):
                let output = String(data: data, encoding: .utf8) ?? ""
                completion(.success(output))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func executeFileCommand(_ command: Command, completion: ((Result<Data, DeviceCtl.Error>) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runFileCommand(command)
            DispatchQueue.main.async {
                completion?(result)
            }
        }
    }

    private static func runFileCommand(_ command: Command) -> Result<Data, DeviceCtl.Error> {
        let task = Foundation.Process()
        task.launchPath = launchPath
        task.arguments = command.arguments

        if let environmentOverrides = command.environmentOverrides {
            var environment = ProcessInfo.processInfo.environment
            environment.merge(environmentOverrides) { _, new in new }
            task.environment = environment
        }

        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        do {
            try task.run()
            task.waitUntilExit()

            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

            guard task.terminationStatus == 0 else {
                let output = stderrData.isEmpty ? stdoutData : stderrData
                let description = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let error = NSError(domain: "DeviceCtl", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: description ?? "Command failed with exit status \(task.terminationStatus)."]) 
                return .failure(.unknown(error))
            }

            return .success(stdoutData)
        } catch {
            return .failure(.unknown(error))
        }
    }

    private static func materializedDirectory(in snapshotDirectory: URL, remoteDirectory: String?) -> URL {
        guard let remoteDirectory else {
            return snapshotDirectory
        }

        let leafName = URL(fileURLWithPath: remoteDirectory).lastPathComponent
        let candidate = snapshotDirectory.appendingPathComponent(leafName, isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : snapshotDirectory
    }

    private static func normalizeRemotePath(_ path: String) -> String? {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        return trimmedPath.isEmpty ? nil : trimmedPath
    }

    private static func explicitRemoteDestination(basePath: String?, sourceURL: URL) -> String? {
        let sourceName = sourceURL.lastPathComponent

        guard let basePath else {
            return sourceName
        }

        return basePath + "/" + sourceName
    }

    private static func parseDisplaySummary(from json: Any) -> String? {
        let displayNode = findValue(in: json) { key in
            let normalizedKey = key.lowercased()
            return normalizedKey == "displays" || normalizedKey.contains("display")
        }

        if let displays = displayNode as? [Any], let firstDisplay = displays.first {
            return formatDisplay(firstDisplay)
        }

        return formatDisplay(json)
    }

    private static func formatDisplay(_ value: Any) -> String? {
        let width = integerValue(findValue(in: value) { $0.lowercased().contains("width") })
        let height = integerValue(findValue(in: value) { $0.lowercased().contains("height") })
        let scaleNumber = numberValue(findValue(in: value) { $0.lowercased() == "scale" || $0.lowercased().contains("scalefactor") })

        var parts: [String] = []

        if let width, let height {
            parts.append("\(width) × \(height)")
        }

        if let scaleNumber {
            let scaleText = scaleNumber == floor(scaleNumber) ? String(Int(scaleNumber)) : String(scaleNumber)
            parts.append("@\(scaleText)x")
        }

        if parts.isNotEmpty {
            return parts.joined(separator: " ")
        }

        return stringValue(findValue(in: value) { $0.lowercased().contains("display") })
    }

    private static func parseLockState(from json: Any) -> String? {
        if let isLocked = boolValue(findValue(in: json) { key in
            let normalizedKey = key.lowercased()
            return normalizedKey == "islocked" || normalizedKey == "locked"
        }) {
            return isLocked ? "Locked" : "Unlocked"
        }

        if let lockString = stringValue(findValue(in: json) { $0.lowercased().contains("lock") }) {
            return lockString.replacingOccurrences(of: "_", with: " ").capitalized
        }

        return nil
    }

    private static func findValue(in value: Any, matchingKey: (String) -> Bool) -> Any? {
        if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                if matchingKey(key) {
                    return nestedValue
                }

                if let result = findValue(in: nestedValue, matchingKey: matchingKey) {
                    return result
                }
            }
        }

        if let array = value as? [Any] {
            for nestedValue in array {
                if let result = findValue(in: nestedValue, matchingKey: matchingKey) {
                    return result
                }
            }
        }

        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func numberValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "true", "yes", "locked", "on":
                return true
            case "false", "no", "unlocked", "off":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
