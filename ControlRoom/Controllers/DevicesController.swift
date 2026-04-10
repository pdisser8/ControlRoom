//
//  DevicesController.swift
//  ControlRoom
//
//  Created by Paul Disser on 2/5/26.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import Combine
import Foundation

/// Loads and tracks connected physical devices using xcrun devicectl.
final class DevicesController: ObservableObject {
    enum LoadingStatus {
        case loading
        case success
        case failed
    }

    @Published var loadingStatus: LoadingStatus = .loading
    @Published var devices: [DeviceCtl.Device] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadDevices()
    }

    func reload() {
        cancellables.removeAll()
        loadingStatus = .loading
        loadDevices()
    }

    private func loadDevices() {
        DeviceCtl.watchDeviceList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    self?.loadingStatus = .success
                case .failure(let error):
                    self?.loadingStatus = .failed
                }
            } receiveValue: { [weak self] list in
                self?.devices = list.devices.sorted { $0.name < $1.name }
                self?.loadingStatus = .success
            }
            .store(in: &cancellables)
    }

}
