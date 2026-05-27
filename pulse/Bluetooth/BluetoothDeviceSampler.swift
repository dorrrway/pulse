import CoreBluetooth
import Foundation
import IOKit
@preconcurrency import IOBluetooth

actor BluetoothDeviceSampler {
    private let systemProfilerURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")

    func snapshot() -> BluetoothDeviceSnapshot {
        let authorization = BluetoothAuthorizationStatus.current
        guard authorization.canSampleDevices else {
            return BluetoothDeviceSnapshot(
                devices: [],
                capturedAt: Date(),
                errorMessage: authorization.isBlocked ? "Bluetooth permission is not available." : nil
            )
        }

        var devicesByID = [String: BluetoothDevice]()
        var errorMessage: String?

        for device in systemProfileDevices() {
            devicesByID[device.id] = devicesByID[device.id]?.merged(with: device) ?? device
        }

        for device in pairedDevices() {
            devicesByID[device.id] = devicesByID[device.id]?.merged(with: device) ?? device
        }

        for (address, battery) in appleHIDBatteryLevelsByAddress() {
            guard let deviceID = devicesByID.values.first(where: { $0.address == address })?.id else {
                continue
            }

            var device = devicesByID[deviceID]
            if device?.batteryLevels.isEmpty == true {
                device?.batteryLevels = [battery]
            }
            devicesByID[deviceID] = device
        }

        if BluetoothAuthorizationStatus.current.isBlocked {
            errorMessage = "Bluetooth permission is not available."
        }

        return BluetoothDeviceSnapshot(
            devices: sortedDevices(Array(devicesByID.values)),
            capturedAt: Date(),
            errorMessage: errorMessage
        )
    }

    func connect(address: String) -> IOReturn {
        guard let device = IOBluetoothDevice(addressString: address) else {
            return kIOReturnNotFound
        }

        return device.openConnection()
    }

    func disconnect(address: String) -> IOReturn {
        guard let device = IOBluetoothDevice(addressString: address) else {
            return kIOReturnNotFound
        }

        return device.closeConnection()
    }

    private func pairedDevices() -> [BluetoothDevice] {
        let rawDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []

        return rawDevices.compactMap { device in
            let address = BluetoothDevice.normalizedAddress(device.addressString)
            let name = device.nameOrAddress ?? address ?? ""
            guard !name.isEmpty else {
                return nil
            }

            return BluetoothDevice(
                id: BluetoothDevice.stableID(address: address, name: name),
                name: name,
                address: address,
                category: category(for: device, fallbackName: name),
                connectionState: device.isConnected() ? .connected : .disconnected
            )
        }
    }

    private func category(for device: IOBluetoothDevice, fallbackName: String) -> BluetoothDeviceCategory {
        let inferred = BluetoothDeviceCategory.inferred(name: fallbackName, minorType: nil)
        if inferred != .unknown {
            return inferred
        }

        let major = Int(device.deviceClassMajor)
        let minor = Int(device.deviceClassMinor)

        if major == 0x05 {
            if minor == 0x40 {
                return .keyboard
            }

            if minor == 0x80 {
                return .mouse
            }
        }

        if major == 0x04 {
            return .headphones
        }

        return .inferred(name: fallbackName, minorType: nil)
    }

    private func appleHIDBatteryLevelsByAddress() -> [String: BluetoothBatteryLevel] {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleDeviceManagementHIDEventService"),
            &iterator
        )
        guard result == KERN_SUCCESS else {
            return [:]
        }

        defer {
            IOObjectRelease(iterator)
        }

        var batteries = [String: BluetoothBatteryLevel]()
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else {
                break
            }

            defer {
                IOObjectRelease(service)
            }

            guard
                registryString("Transport", service: service) == "Bluetooth",
                let address = BluetoothDevice.normalizedAddress(registryString("DeviceAddress", service: service)),
                let percentage = registryDouble("BatteryPercent", service: service)
            else {
                continue
            }

            batteries[address] = BluetoothBatteryLevel(role: .device, percentage: percentage / 100)
        }

        return batteries
    }

    private func registryString(_ key: String, service: io_object_t) -> String? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }

    private func registryDouble(_ key: String, service: io_object_t) -> Double? {
        let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let integer = value as? Int {
            return Double(integer)
        }

        return nil
    }

    private func systemProfileDevices() -> [BluetoothDevice] {
        guard let data = systemProfileData() else {
            return []
        }

        let profile: SystemBluetoothProfile
        do {
            profile = try JSONDecoder().decode(SystemBluetoothProfile.self, from: data)
        } catch {
            return []
        }

        return profile.controllers.flatMap { controller in
            controller.devices(connectionState: .connected) + controller.devices(connectionState: .disconnected)
        }
    }

    private func systemProfileData() -> Data? {
        let process = Process()
        process.executableURL = systemProfilerURL
        process.arguments = ["SPBluetoothDataType", "-detailLevel", "basic", "-json"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        return output.fileHandleForReading.readDataToEndOfFile()
    }

    private func sortedDevices(_ devices: [BluetoothDevice]) -> [BluetoothDevice] {
        devices.sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected {
                return lhs.isConnected
            }

            let leftCategory = categorySortIndex(lhs.category)
            let rightCategory = categorySortIndex(rhs.category)
            if leftCategory != rightCategory {
                return leftCategory < rightCategory
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func categorySortIndex(_ category: BluetoothDeviceCategory) -> Int {
        switch category {
        case .headphones:
            0
        case .keyboard:
            1
        case .trackpad:
            2
        case .mouse:
            3
        case .phone, .tablet, .computer:
            4
        case .unknown:
            5
        }
    }
}

private nonisolated struct SystemBluetoothProfile: Decodable {
    var controllers: [SystemBluetoothController]

    enum CodingKeys: String, CodingKey {
        case controllers = "SPBluetoothDataType"
    }
}

private nonisolated struct SystemBluetoothController: Decodable {
    var connected: [[String: SystemBluetoothDevice]]?
    var notConnected: [[String: SystemBluetoothDevice]]?

    enum CodingKeys: String, CodingKey {
        case connected = "device_connected"
        case notConnected = "device_not_connected"
    }

    nonisolated func devices(connectionState: BluetoothDeviceConnectionState) -> [BluetoothDevice] {
        let source = connectionState == .connected ? connected : notConnected

        return source?.flatMap { entry in
            entry.compactMap { name, device in
                device.bluetoothDevice(name: name, connectionState: connectionState)
            }
        } ?? []
    }
}

private nonisolated struct SystemBluetoothDevice: Decodable {
    var address: String?
    var minorType: String?
    var batteryLevel: String?
    var batteryLevelLeft: String?
    var batteryLevelRight: String?
    var batteryLevelCase: String?

    enum CodingKeys: String, CodingKey {
        case address = "device_address"
        case minorType = "device_minorType"
        case batteryLevel = "device_batteryLevel"
        case batteryLevelLeft = "device_batteryLevelLeft"
        case batteryLevelRight = "device_batteryLevelRight"
        case batteryLevelCase = "device_batteryLevelCase"
    }

    nonisolated func bluetoothDevice(
        name: String,
        connectionState: BluetoothDeviceConnectionState
    ) -> BluetoothDevice? {
        let address = BluetoothDevice.normalizedAddress(address)
        let levels = [
            BluetoothBatteryLevel.parsed(role: .left, value: batteryLevelLeft),
            BluetoothBatteryLevel.parsed(role: .right, value: batteryLevelRight),
            BluetoothBatteryLevel.parsed(role: .case, value: batteryLevelCase),
            BluetoothBatteryLevel.parsed(role: .device, value: batteryLevel),
        ].compactMap { $0 }

        guard address != nil || !levels.isEmpty else {
            return nil
        }

        return BluetoothDevice(
            id: BluetoothDevice.stableID(address: address, name: name),
            name: name,
            address: address,
            category: .inferred(name: name, minorType: minorType),
            connectionState: connectionState,
            batteryLevels: levels
        )
    }
}
