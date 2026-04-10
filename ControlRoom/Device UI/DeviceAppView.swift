//
//  AppView.swift
//  ControlRoom
//
//  Created by Paul Hudson on 12/02/2020.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import SwiftUI
import Combine

/// Controls features relating to one specific app.
struct DeviceAppView: View {
    @EnvironmentObject var preferences: Preferences

    @AppStorage("CRApps_ShowSystemApps") private var shouldShowSystemApps = true
    @AppStorage("CRApps_LastBundleID") private var lastBundleID = ""
    @State private var applications: [Application] = []
    @State private var allApplications: [Application] = []
    @State private var appsCancellable: AnyCancellable?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var appFiles: [DeviceCtl.AppFile] = []

    let device: DeviceCtl.Device

    /// The selected application we want to manipulate.
    private var selectedApplication: Application {
        applications.first(where: { $0.bundleIdentifier == lastBundleID })
            ?? .default
    }

    /// The current permission option the user has selected to grant, reset, or revoke.
    @State private var resetPermission: SimCtl.Privacy.Permission = .all

    /// If true shows the uninstall confirmation alert.
    @State private var shouldShowUninstallConfirmationAlert: Bool = false

    init(device: DeviceCtl.Device) {
        self.device = device
    }

    var body: some View {
        let apps = applications.filter { $0.type == .user || shouldShowSystemApps }.sorted()
        let selectedApplication = apps.first(where: { $0.bundleIdentifier == lastBundleID }) ?? .default
        let isApplicationSelected = selectedApplication.bundleIdentifier.isNotEmpty

        ScrollView {
            Form {
                Section {
                    HStack {
                        Picker("Application:", selection: $lastBundleID) {
                            ForEach(apps, id: \.bundleIdentifier) { application in
                                Text("\(application.displayName) – \(application.bundleIdentifier)")
                                    .tag(application.bundleIdentifier)
                            }
                        }
                        .pickerStyle(.menu)
                        Toggle("Show system apps", isOn: $shouldShowSystemApps)
                    }

                    HStack {
                        AppSummaryView(application: selectedApplication)
                        Spacer()
                        VStack(alignment: .trailing) {
                            HStack {
                                Button("Launch", action: launchApp)
                                Button("Terminate", action: terminateApp)
                                Button("Restart", action: restartApp)
                                Button("Uninstall", action: confirmDeleteApp)
                            }
                            .disabled(selectedApplication == .default)

                            HStack{
                                Button("Load app folder", action: openDataFolder)
                                    .disabled(selectedApplication.url == nil)
                            }
                        }
                    }
                }
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
        .alert(isPresented: $shouldShowUninstallConfirmationAlert) {
            Alert(title: Text("Are you sure you want to permanently delete \(selectedApplication.displayName)"),
                  message: Text("You can’t undo this action."),
                  primaryButton: .destructive(Text("Delete the app"), action: uninstallApp),
                  secondaryButton: .default(Text("Cancel")))
        }
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
            })
    }
}

struct DeviceAppView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceAppView(device: .preview)
            .environmentObject(Preferences())
    }
}
