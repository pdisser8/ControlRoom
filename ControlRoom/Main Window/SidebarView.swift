//
//  SidebarView.swift
//  ControlRoom
//
//  Created by Dave DeLong on 2/12/20.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import SwiftUI

enum SidebarMode {
    case simulators
    case devices
}

/// Shows the list of available simulators, allowing selection, filtering, and deletion.
struct SidebarView: View {
    @EnvironmentObject var preferences: Preferences
    @ObservedObject var controller: SimulatorsController
    @ObservedObject var devicesController: DevicesController
    @Binding var sidebarMode: SidebarMode
    @Binding var selectedDeviceID: String?

    @AppStorage("CRSidebar_FilterText") private var filterText = ""
    @AppStorage("CRLastSimulatorUDID") private var lastSimulatorUDID = "booted"

    @State private var shouldShowDeleteAlert = false

    private var selectedSimulatorsSummary: String {
        guard controller.selectedSimulators.count > 0 else { return "" }

        switch controller.selectedSimulators.count {
        case 1:
            return controller.selectedSimulators[0].summary
        default:
            let simulatorsSummaries = controller.selectedSimulators.map { "• \($0.summary)" }.joined(separator: "\n")
            return "the following simulators? \n\n\(simulatorsSummaries)"
        }
    }

    private var filteredDevices: [DeviceCtl.Device] {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let devices = devicesController.devices

        guard trimmed.isNotEmpty else { return devices }
        return devices.filter { $0.name.localizedCaseInsensitiveContains(trimmed) || $0.udid.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sidebarMode) {
                Text("Simulators").tag(SidebarMode.simulators)
                Text("Devices").tag(SidebarMode.devices)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 8)
            .padding(.bottom, 4)

            Group {
                switch sidebarMode {
                case .simulators:
                    List(selection: $controller.selectedSimulatorIDs.onChange(updateSelectedSimulators)) {
                        if controller.simulators.isEmpty {
                            Text("No simulators")
                        } else {
                            ForEach(SimCtl.DeviceFamily.allCases, id: \.self, content: section)
                        }
                    }
                    .contextMenu {
                        if controller.selectedSimulatorIDs.isNotEmpty {
                            Button("Delete...") {
                                shouldShowDeleteAlert = true
                            }
                        }
                    }
                    .listStyle(.sidebar)
                case .devices:
                    List(selection: $selectedDeviceID) {
                        switch devicesController.loadingStatus {
                        case .loading:
                            Text("Loading devices…")
                        case .failed:
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Failed to load devices")
                            }
                        case .success:
                            if filteredDevices.isEmpty {
                                Text("No devices found")
                            } else {
                                ForEach(filteredDevices) { device in
                                    DeviceSidebarView(device: device)
                                        .tag(device.id)
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }

            Divider()

            HStack(spacing: 4) {
                Button {
                    preferences.shouldShowOnlyActiveDevices.toggle()
                    controller.filterSimulators()
                } label: {
                    Image(systemName: "power")
                        .resizable()
                        .foregroundColor(preferences.shouldShowOnlyActiveDevices ? .accentColor : .secondary)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16)
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 3)
                .help("Show \(preferences.shouldShowOnlyActiveDevices ? "all" : "only active") devices")

                SearchField("Filter", text: $filterText.onChange(controller.filterSimulators), onClear: {})
            }
            .padding(2)
            .sheet(isPresented: $shouldShowDeleteAlert) {
                SimulatorActionSheet(
                    icon: controller.selectedSimulators[0].image,
                    message: "Delete Simulators?",
                    informativeText: "Are you sure you want to delete the selected simulators? You will not be able to undo this action.",
                    confirmationTitle: "Delete",
                    confirm: deleteSelectedSimulators,
                    content: { EmptyView() }
                )
            }
        }
        .onChange(of: sidebarMode) { newMode in
            if newMode == .devices {
                devicesController.reload()
                controller.selectedSimulatorIDs.removeAll()
            }
        }
    }

    private func section(for family: SimCtl.DeviceFamily) -> some View {
        let simulators = controller.simulators.filter { $0.deviceFamily == family }
        let canShowContext = controller.selectedSimulatorIDs.count < 2

        return Group {
            if simulators.isEmpty {
                EmptyView()
            } else {
                Section(header: Text(family.displayName)) {
                    ForEach(simulators) { simulator in
                        SimulatorSidebarView(simulator: simulator, canShowContextualMenu: canShowContext)
                            .tag(simulator.udid)
                    }
                }
            }
        }
    }

    /// Deletes all simulators that are currently selected.
    func deleteSelectedSimulators() {
        guard controller.selectedSimulatorIDs.isNotEmpty else { return }
        SimCtl.delete(controller.selectedSimulatorIDs)
    }

    /// Called whenever the user adjusts their selection of simulator.
    func updateSelectedSimulators() {
        // If we selected exactly one simulator, stash its UDID away so we can
        // quickly use it elsewhere in the app, e.g. in the menu bar icon.
        if controller.selectedSimulatorIDs.count == 1 {
            lastSimulatorUDID = controller.selectedSimulators.first!.udid
        }
    }
}

private extension Simulator {
    var summary: String {
        [name, runtime?.name].compactMap { $0 }.joined(separator: " - ")
    }
}

struct SidebarView_Previews: PreviewProvider {
    @State static var selected: Simulator?

    static var previews: some View {
        let preferences = Preferences()
        SidebarView(
            controller: SimulatorsController(preferences: preferences),
            devicesController: DevicesController(),
            sidebarMode: .constant(.simulators),
            selectedDeviceID: .constant(nil)
        )
        .environmentObject(preferences)
    }
}
