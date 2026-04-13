//
//  AppView.swift
//  ControlRoom
//
//  Created by Paul Hudson on 12/02/2020.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import SwiftUI
import Combine
import AppKit

/// Controls features relating to one specific app.
struct DeviceAppView: View {
    @EnvironmentObject var preferences: Preferences

    @AppStorage("CRApps_ShowSystemApps") private var shouldShowSystemApps = true
    @AppStorage("CRApps_LastBundleID") private var lastBundleID = ""
    @State private var applications: [Application] = []
    @State private var allApplications: [Application] = []
    @State private var appsCancellable: AnyCancellable?
    @State private var filesCancellable: AnyCancellable?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var appFiles: [DeviceCtl.AppFile] = []
    @State private var currentDirectory = ""
    @State private var selectedFilePaths = Set<String>()
    @State private var explorerMessage = ""
    @State private var isLoadingFiles = false
    @State private var isPerformingFileOperation = false
    @State private var shouldShowDeleteFilesConfirmation = false

    let device: DeviceCtl.Device

    /// The selected application we want to manipulate.
    private var selectedApplication: Application {
        applications.first(where: { $0.bundleIdentifier == lastBundleID })
            ?? .default
    }

    private var visibleApplications: [Application] {
        applications
            .filter { $0.type == .user || shouldShowSystemApps }
            .sorted()
    }

    private var currentApplication: Application {
        visibleApplications.first(where: { $0.bundleIdentifier == lastBundleID }) ?? .default
    }

    private var isApplicationSelected: Bool {
        currentApplication.bundleIdentifier.isNotEmpty
    }

    private var supportsFileOperations: Bool {
        currentApplication.type == .user
    }

    private var fileOperationsDisabledReason: String {
        "File browsing and transfer are available only for apps installed as development builds."
    }

    private var explorerEntries: [ExplorerEntry] {
        appFiles
            .map { file in
                let fullPath = currentDirectory.isEmpty ? file.name : currentDirectory + "/" + file.name
                return ExplorerEntry(
                    id: fullPath,
                    name: file.name,
                    isDirectory: file.isDirectory,
                    size: file.size,
                    lastModified: file.lastModDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private var selectedExplorerEntries: [ExplorerEntry] {
        explorerEntries.filter { selectedFilePaths.contains($0.id) }
    }

    private var displayedDirectory: String {
        currentDirectory.isEmpty ? "/" : "/" + currentDirectory
    }

    /// The current permission option the user has selected to grant, reset, or revoke.
    @State private var resetPermission: SimCtl.Privacy.Permission = .all

    /// If true shows the uninstall confirmation alert.
    @State private var shouldShowUninstallConfirmationAlert: Bool = false

    init(device: DeviceCtl.Device) {
        self.device = device
    }

    var body: some View {
        ScrollView {
            Form {
                applicationSection
                filesSection
            }
            .padding()
        }
        .tabItem() {
            Text("App")
        }
        .onAppear() {
            loadApplications()
        }
        .onChange(of: shouldShowSystemApps) { _ in
            loadApplications()
        }
        .onChange(of: lastBundleID) { _ in
            currentDirectory = ""
            selectedFilePaths.removeAll()
            refreshFiles()
        }
        .alert(isPresented: $shouldShowUninstallConfirmationAlert) {
            Alert(title: Text("Are you sure you want to permanently delete \(currentApplication.displayName)"),
                  message: Text("You can’t undo this action."),
                  primaryButton: .destructive(Text("Delete the app"), action: uninstallApp),
                  secondaryButton: .default(Text("Cancel")))
        }
        .alert("Delete selected items?", isPresented: $shouldShowDeleteFilesConfirmation) {
            Button("Delete", role: .destructive, action: deleteSelectedFiles)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(selectedExplorerEntries.map(\.name).joined(separator: ", "))
        }
    }

    private var applicationSection: some View {
        Section {
            applicationPickerRow
            applicationSummaryRow
        }
    }

    private var applicationPickerRow: some View {
        HStack {
            Picker("Application:", selection: $lastBundleID) {
                ForEach(visibleApplications, id: \.bundleIdentifier) { application in
                    Text("\(application.displayName) – \(application.bundleIdentifier)")
                        .tag(application.bundleIdentifier)
                }
            }
            .pickerStyle(.menu)

            Toggle("Show system apps", isOn: $shouldShowSystemApps)
        }
    }

    private var applicationSummaryRow: some View {
        HStack {
            AppSummaryView(application: currentApplication)
            Spacer()

            VStack(alignment: .trailing) {
                HStack {
                    Button("Launch", action: launchApp)
                    Button("Terminate", action: terminateApp)
                    Button("Restart", action: restartApp)
                    Button("Uninstall", action: confirmDeleteApp)
                }
                .disabled(currentApplication == .default)

                HStack {
                    Button("Refresh Files", action: refreshFiles)
                        .disabled(!isApplicationSelected || isLoadingFiles || isPerformingFileOperation)
                }
            }
        }
    }

    private var filesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                filesToolbarRow

                if explorerMessage.isNotEmpty {
                    Text(explorerMessage)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                if isApplicationSelected && !supportsFileOperations {
                    Label(fileOperationsDisabledReason, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                filesContentView
            }
        } header: {
            Text("Files")
        }
    }

    private var filesToolbarRow: some View {
        HStack {
            Text("Current folder:")
                .foregroundColor(.secondary)
            Text(displayedDirectory)
                .textSelection(.enabled)

            Spacer()

            Button("Go Up One Level", action: navigateUp)
                .disabled(currentDirectory.isEmpty || isLoadingFiles || isPerformingFileOperation || !supportsFileOperations)
            Button("Add File to iPad", action: uploadFiles)
                .disabled(!isApplicationSelected || isLoadingFiles || isPerformingFileOperation || !supportsFileOperations)
            Button("Add File to Mac", action: downloadSelectedFiles)
                .disabled(selectedExplorerEntries.isEmpty || isLoadingFiles || isPerformingFileOperation || !supportsFileOperations)
            Button("Delete", role: .destructive, action: confirmDeleteFiles)
                .disabled(selectedExplorerEntries.isEmpty || isLoadingFiles || isPerformingFileOperation || !supportsFileOperations)
        }
    }

    @ViewBuilder
    private var filesContentView: some View {
        if isApplicationSelected && supportsFileOperations {
            Table(explorerEntries, selection: $selectedFilePaths) {
                TableColumn("Name", content: nameCell)
                TableColumn("Size", content: sizeCell)
                TableColumn("Modified", content: modifiedCell)
            }
            .frame(minHeight: 300)
        } else if isApplicationSelected {
            Text(fileOperationsDisabledReason)
                .foregroundColor(.secondary)
        } else {
            Text("Select an app to browse its data container.")
                .foregroundColor(.secondary)
        }
    }

    private func nameCell(for entry: ExplorerEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(entry.isDirectory ? Color.accentColor : Color.secondary)
            Text(entry.name)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            open(entry)
        }
    }

    private func sizeCell(for entry: ExplorerEntry) -> some View {
        Text(entry.sizeText)
            .foregroundColor(.secondary)
    }

    private func modifiedCell(for entry: ExplorerEntry) -> some View {
        Text(entry.modifiedText)
            .foregroundColor(.secondary)
    }

    /// Launches the currently selected app.
    func launchApp() {
        DeviceCtl.launch(device.udid, appID: lastBundleID)
    }

    /// Terminates the currently selected app.
    func terminateApp() {
        DeviceCtl.findPid(for: lastBundleID, on: device.udid)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to find PID for \(self.lastBundleID): \(error)")
                }
            }, receiveValue: { pid in
                guard let pid = pid else {
                    print("⚠️ No running process found for \(self.lastBundleID)")
                    return
                }
                print("🔪 Terminating process \(pid) for \(self.lastBundleID)")
                DeviceCtl.terminate(self.device.udid, pid: pid)
            })
            .store(in: &cancellables)
    }

    /// Terminates the currently selected app, then restarts it immediately.
    func restartApp() {
        DeviceCtl.findPid(for: lastBundleID, on: device.udid)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to find PID for \(self.lastBundleID): \(error)")
                }
            }, receiveValue: { pid in
                guard let pid = pid else {
                    print("⚠️ No running process found for \(self.lastBundleID), launching instead")
                    self.launchApp()
                    return
                }
                print("🔄 Restarting process \(pid) for \(self.lastBundleID)")
                DeviceCtl.terminate(self.device.udid, pid: pid) { _ in
                    // Wait a bit then relaunch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.launchApp()
                    }
                }
            })
            .store(in: &cancellables)
    }

    /// Reveals the app's container directory in Finder.
    func openDataFolder() {
        refreshFiles()
    }

    /// Shows a confirmation alert asking the user if they are sure they want to delete the selected app.
    func confirmDeleteApp() {
        shouldShowUninstallConfirmationAlert = true
    }

    /// Removes the identified app from the device.
    func uninstallApp() {
        DeviceCtl.uninstall(device.udid, appID: selectedApplication.bundleIdentifier)
    }
    
    /// Loads the list of applications from the device using devicectl.
    private func loadApplications() {
        print("📱 Loading applications for device: \(device.udid)")
        appsCancellable = DeviceCtl.listApplications(device.udid, includeAllApps: shouldShowSystemApps)
            .catch { error -> Just<DeviceCtl.ApplicationsList> in
                print("⚠️ Error loading applications: \(error)")
                return Just(DeviceCtl.ApplicationsList(apps: []))
            }
            .map { appsList -> [Application] in
                let apps = appsList.apps.compactMap(Application.init)
                print("✅ Loaded \(apps.count) applications from devicectl")
                return apps
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                print("🏁 Applications load completed: \(completion)")
            }, receiveValue: { apps in
                print("📦 Received \(apps.count) applications in view")
                self.allApplications = apps
                self.applications = apps

                if self.lastBundleID.isEmpty || apps.contains(where: { $0.bundleIdentifier == self.lastBundleID }) == false {
                    self.lastBundleID = apps.first?.bundleIdentifier ?? ""
                }

                self.refreshFiles()
            })
    }

    private func refreshFiles() {
        guard selectedApplication.bundleIdentifier.isNotEmpty else {
            appFiles = []
            explorerMessage = ""
            return
        }

        guard supportsFileOperations else {
            appFiles = []
            selectedFilePaths.removeAll()
            explorerMessage = fileOperationsDisabledReason
            return
        }

        isLoadingFiles = true
        explorerMessage = "Loading \(displayedDirectory)…"

        let publisher: AnyPublisher<DeviceCtl.ApplicationFilesList, DeviceCtl.Error>
        if currentDirectory.isEmpty {
            publisher = DeviceCtl.listApplicationFiles(device.udid, appBundleId: selectedApplication.bundleIdentifier)
        } else {
            publisher = DeviceCtl.listApplicationFiles(device.udid, appBundleId: selectedApplication.bundleIdentifier, subdirectory: currentDirectory)
        }

        filesCancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoadingFiles = false

                if case .failure(let error) = completion {
                    self.appFiles = []
                    self.explorerMessage = self.message(for: error)
                }
            }, receiveValue: { filesList in
                self.selectedFilePaths.removeAll()
                self.appFiles = filesList.appFiles
                self.explorerMessage = filesList.appFiles.isEmpty ? "This folder is empty." : ""
            })
    }

    private func navigateUp() {
        guard currentDirectory.isNotEmpty else { return }

        let pathComponents = currentDirectory.split(separator: "/").dropLast()
        currentDirectory = pathComponents.joined(separator: "/")
        refreshFiles()
    }

    private func open(_ entry: ExplorerEntry) {
        guard entry.isDirectory else { return }
        currentDirectory = entry.id
        refreshFiles()
    }

    private func uploadFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Upload"

        guard panel.runModal() == .OK else { return }

        let urls = panel.urls
        guard urls.isNotEmpty else { return }

        isPerformingFileOperation = true
        explorerMessage = "Uploading \(urls.count) item\(urls.count == 1 ? "" : "s")…"

        DeviceCtl.copyItemsToApplicationContainer(device.udid, appBundleId: selectedApplication.bundleIdentifier, sourceURLs: urls, destinationPath: currentDirectory) { result in
            self.isPerformingFileOperation = false

            switch result {
            case .success:
                self.explorerMessage = "Upload complete."
                self.refreshFiles()
            case .failure(let error):
                self.explorerMessage = self.message(for: error)
            }
        }
    }

    private func downloadSelectedFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let destinationDirectory = panel.url else { return }

        isPerformingFileOperation = true
        explorerMessage = "Downloading \(selectedExplorerEntries.count) item\(selectedExplorerEntries.count == 1 ? "" : "s")…"

        DeviceCtl.copyItemsFromApplicationContainer(device.udid, appBundleId: selectedApplication.bundleIdentifier, sourcePaths: selectedExplorerEntries.map(\.id), destinationDirectory: destinationDirectory) { result in
            self.isPerformingFileOperation = false

            switch result {
            case .success:
                self.explorerMessage = "Download complete."
            case .failure(let error):
                self.explorerMessage = self.message(for: error)
            }
        }
    }

    private func confirmDeleteFiles() {
        shouldShowDeleteFilesConfirmation = true
    }

    private func deleteSelectedFiles() {
        let names = selectedExplorerEntries.map(\.name)

        isPerformingFileOperation = true
        explorerMessage = "Deleting \(names.count) item\(names.count == 1 ? "" : "s")…"

        DeviceCtl.deleteItemsFromApplicationContainer(device.udid, appBundleId: selectedApplication.bundleIdentifier, itemNames: names, inDirectory: currentDirectory) { result in
            self.isPerformingFileOperation = false

            switch result {
            case .success:
                self.explorerMessage = "Delete complete."
                self.refreshFiles()
            case .failure(let error):
                self.explorerMessage = self.message(for: error)
            }
        }
    }

    private func message(for error: DeviceCtl.Error) -> String {
        switch error {
        case .missingCommand:
            return "xcrun could not be launched."
        case .missingOutput:
            return "The device did not return the expected response."
        case .unknown(let underlyingError):
            let description = underlyingError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return description.isEmpty ? "The file operation failed." : description
        }
    }
}

private extension DeviceAppView {
    struct ExplorerEntry: Identifiable, Hashable {
        let id: String
        let name: String
        let isDirectory: Bool
        let size: Int?
        let lastModified: Date?

        var sizeText: String {
            guard let size else { return "—" }
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }

        var modifiedText: String {
            guard let lastModified else { return "—" }
            return DeviceAppView.fileDateFormatter.string(from: lastModified)
        }
    }

    static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct DeviceAppView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceAppView(device: .preview)
            .environmentObject(Preferences())
    }
}
