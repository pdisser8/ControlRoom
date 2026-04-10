//
//  DeviceCtlSubCommandsTests.swift
//  ControlRoomTests
//
//  Created by GitHub Copilot on 1/28/26.
//

@testable import Control_Room
import XCTest

final class DeviceCtlSubCommandsTests: XCTestCase {

    func testListDevicesWithJSONOutputFlag() throws {
        let command: DeviceCtl.Command = .list(.devices(), flags: [.jsonOutput("/tmp/out.json")])
        XCTAssertEqual(command.arguments, ["devicectl", "list", "devices", "--json-output", "/tmp/out.json"])
    }

    func testDeviceListDecoding() throws {
        let json = """
        {
          "result": {
            "devices": [
              {
                "hardwareProperties": { "udid": "1111-2222", "platform": "ios" },
                "deviceProperties": { "name": "John's iPhone", "osVersionNumber": "17.2" },
                "connectionProperties": { "pairingState": "paired", "tunnelState": "connected", "transportType": "wired" }
              },
              {
                "hardwareProperties": { "udid": "3333-4444", "platform": "tvos" },
                "deviceProperties": { "name": "Apple TV", "osVersionNumber": "17.1" },
                "connectionProperties": { "pairingState": "paired", "tunnelState": "unavailable", "transportType": "wifi" }
              }
            ]
          }
        }
        """

        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(DeviceCtl.DeviceList.self, from: data)

        XCTAssertEqual(decoded.devices.count, 2)
        XCTAssertEqual(decoded.devices[0].name, "John's iPhone")
        XCTAssertEqual(decoded.devices[0].platform, .iOS)
        XCTAssertEqual(decoded.devices[0].connectionState, .connected)
        XCTAssertEqual(decoded.devices[1].platform, .tvOS)
        XCTAssertEqual(decoded.devices[1].connectionState, .disconnected)
    }
}
