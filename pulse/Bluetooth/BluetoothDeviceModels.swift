import Foundation

nonisolated enum BluetoothAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
    case restricted

    var canSampleDevices: Bool {
        self == .allowed
    }

    var needsInitialRequest: Bool {
        self == .notDetermined
    }

    var isBlocked: Bool {
        self == .denied || self == .restricted
    }
}

nonisolated enum BluetoothPowerState: Equatable, Sendable {
    case unknown
    case poweredOn
    case poweredOff
    case unavailable

    var canSampleDevices: Bool {
        switch self {
        case .unknown, .poweredOn:
            true
        case .poweredOff, .unavailable:
            false
        }
    }
}

nonisolated enum BluetoothDeviceCategory: String, Codable, Sendable {
    case keyboard
    case trackpad
    case mouse
    case headphones
    case phone
    case tablet
    case computer
    case unknown

    static func inferred(name: String, minorType: String?) -> Self {
        let text = ([name, minorType].compactMap { $0 }.joined(separator: " ")).lowercased()

        if text.contains("airpods") || text.contains("headphone") || text.contains("earbud") {
            return .headphones
        }

        if text.contains("trackpad") {
            return .trackpad
        }

        if text.contains("keyboard") {
            return .keyboard
        }

        if text.contains("mouse") {
            return .mouse
        }

        if text.contains("iphone") {
            return .phone
        }

        if text.contains("ipad") {
            return .tablet
        }

        if text.contains("macbook") || text.contains("mac") {
            return .computer
        }

        return .unknown
    }
}

nonisolated enum BluetoothDeviceConnectionState: String, Codable, Sendable {
    case connected
    case disconnected
}

nonisolated enum BluetoothBatteryRole: String, Codable, Sendable {
    case device
    case left
    case right
    case `case`
}

nonisolated struct BluetoothDeviceSymbol: Equatable, Sendable {
    var candidates: [String]

    static let fallbackName = "dot.radiowaves.left.and.right"

    init(_ candidates: [String]) {
        self.candidates = candidates + [Self.fallbackName]
    }

    static func row(for device: BluetoothDevice) -> Self {
        let profile = BluetoothAudioSymbolProfile(name: device.name)
        if let candidates = profile.rowCandidates {
            return Self(candidates)
        }

        switch device.category {
        case .keyboard:
            return Self(["keyboard"])
        case .trackpad:
            return Self(["trackpad", "rectangle.and.hand.point.up.left"])
        case .mouse:
            return Self(["magicmouse", "computermouse"])
        case .headphones:
            return Self(["headphones", "earbuds"])
        case .phone:
            return Self(["iphone"])
        case .tablet:
            return Self(["ipad"])
        case .computer:
            return Self(["macbook", "laptopcomputer", "desktopcomputer"])
        case .unknown:
            return Self([fallbackName])
        }
    }

    static func battery(for device: BluetoothDevice, role: BluetoothBatteryRole) -> Self {
        let profile = BluetoothAudioSymbolProfile(name: device.name)
        if let candidates = profile.batteryCandidates(role: role) {
            return Self(candidates)
        }

        switch role {
        case .device:
            if device.category == .headphones {
                return row(for: device)
            }

            return Self(["battery.75percent"])
        case .left:
            return Self(["earbud.left", "earpods"])
        case .right:
            return Self(["earbud.right", "earpods"])
        case .case:
            return Self(["earbuds.case", "battery.75percent"])
        }
    }
}

private nonisolated struct BluetoothAudioSymbolProfile {
    private var normalizedName: String

    init(name: String) {
        normalizedName = name.lowercased()
    }

    var rowCandidates: [String]? {
        if let symbolSet = BluetoothAudioSymbolSet.matching(normalizedName) {
            return symbolSet.rowCandidates
        }

        if normalizedName.contains("homepod mini") {
            return ["homepod.mini", "homepod"]
        }

        if normalizedName.contains("homepod") {
            return ["homepod", "speaker.wave.2"]
        }

        if normalizedName.contains("headset") {
            return ["headset", "headphones"]
        }

        return nil
    }

    func batteryCandidates(role: BluetoothBatteryRole) -> [String]? {
        if let symbolSet = BluetoothAudioSymbolSet.matching(normalizedName) {
            return symbolSet.candidates(for: role)
        }

        return nil
    }
}

private nonisolated struct BluetoothAudioSymbolSet: Sendable {
    var matchTerms: [String]
    var rowCandidates: [String]
    var deviceCandidates: [String]
    var leftCandidates: [String]? = nil
    var rightCandidates: [String]? = nil
    var caseCandidates: [String]? = nil

    func candidates(for role: BluetoothBatteryRole) -> [String]? {
        switch role {
        case .device:
            deviceCandidates
        case .left:
            leftCandidates
        case .right:
            rightCandidates
        case .case:
            caseCandidates
        }
    }

    static func matching(_ normalizedName: String) -> Self? {
        all.first { symbolSet in
            symbolSet.matchTerms.contains { normalizedName.contains($0) }
        }
    }

    private static let all: [Self] = [
        Self(
            matchTerms: ["airpods max"],
            rowCandidates: ["airpods.max", "headphones"],
            deviceCandidates: ["airpods.max", "headphones"]
        ),
        Self(
            matchTerms: ["airpods pro", "airpodspro"],
            rowCandidates: ["airpods.pro", "airpods", "earbuds"],
            deviceCandidates: ["airpods.pro", "airpods", "earbuds"],
            leftCandidates: ["airpods.pro.left", "airpod.left", "earbud.left"],
            rightCandidates: ["airpods.pro.right", "airpod.right", "earbud.right"],
            caseCandidates: [
                "airpods.pro.chargingcase.wireless",
                "airpods.pro.chargingcase.wireless.fill",
                "airpodspro.chargingcase.wireless",
                "airpods.chargingcase.wireless",
                "airpods.chargingcase",
                "earbuds.case",
            ]
        ),
        Self(
            matchTerms: ["airpods gen 4", "airpods gen4", "airpods 4", "airpods4", "airpods (4", "airpods fourth", "airpods 4th"],
            rowCandidates: ["airpods.gen4", "airpods", "earbuds"],
            deviceCandidates: ["airpods.gen4", "airpods", "earbuds"],
            leftCandidates: ["airpods.gen4.left", "airpod.left", "earbud.left"],
            rightCandidates: ["airpods.gen4.right", "airpod.right", "earbud.right"],
            caseCandidates: [
                "airpods.gen4.chargingcase.wireless",
                "airpods.gen4.chargingcase.wireless.fill",
                "airpods.chargingcase.wireless",
                "airpods.chargingcase",
                "earbuds.case",
            ]
        ),
        Self(
            matchTerms: ["airpods gen 3", "airpods gen3", "airpods 3", "airpods3", "airpods (3", "airpods third", "airpods 3rd"],
            rowCandidates: ["airpods.gen3", "airpods", "earbuds"],
            deviceCandidates: ["airpods.gen3", "airpods", "earbuds"],
            leftCandidates: ["airpod.gen3.left", "airpod.left", "earbud.left"],
            rightCandidates: ["airpod.gen3.right", "airpod.right", "earbud.right"],
            caseCandidates: [
                "airpods.gen3.chargingcase.wireless",
                "airpods.gen3.chargingcase.wireless.fill",
                "airpods.chargingcase.wireless",
                "airpods.chargingcase",
                "earbuds.case",
            ]
        ),
        Self(
            matchTerms: ["airpods"],
            rowCandidates: ["airpods", "earpods", "earbuds"],
            deviceCandidates: ["airpods", "earpods", "earbuds"],
            leftCandidates: ["airpod.left", "earbud.left"],
            rightCandidates: ["airpod.right", "earbud.right"],
            caseCandidates: ["airpods.chargingcase", "airpods.chargingcase.wireless", "earbuds.case"]
        ),
        Self(
            matchTerms: ["earpods"],
            rowCandidates: ["earpods", "earbuds"],
            deviceCandidates: ["earpods", "earbuds"],
            leftCandidates: ["airpod.left", "earbud.left"],
            rightCandidates: ["airpod.right", "earbud.right"]
        ),
        Self(
            matchTerms: ["beats fit pro", "beats fitpro"],
            rowCandidates: ["beats.fitpro", "beats.earphones", "earbuds"],
            deviceCandidates: ["beats.fitpro", "beats.earphones", "earbuds"],
            leftCandidates: ["beats.fitpro.left", "earbud.left"],
            rightCandidates: ["beats.fitpro.right", "earbud.right"],
            caseCandidates: ["beats.fitpro.chargingcase", "beats.fitpro.chargingcase.fill", "earbuds.case"]
        ),
        Self(
            matchTerms: ["beats studio buds plus", "beats studiobudsplus", "beats studio buds+"],
            rowCandidates: ["beats.studiobuds.plus", "beats.studiobuds", "beats.earphones", "earbuds"],
            deviceCandidates: ["beats.studiobuds.plus", "beats.studiobuds", "beats.earphones", "earbuds"],
            leftCandidates: ["beats.studiobuds.plus.left", "beats.studiobuds.left", "earbud.left"],
            rightCandidates: ["beats.studiobuds.plus.right", "beats.studiobuds.right", "earbud.right"],
            caseCandidates: ["beats.studiobuds.plus.chargingcase", "beats.studiobuds.plus.chargingcase.fill", "beats.studiobuds.chargingcase", "earbuds.case"]
        ),
        Self(
            matchTerms: ["beats studio buds", "beats studiobuds"],
            rowCandidates: ["beats.studiobuds", "beats.earphones", "earbuds"],
            deviceCandidates: ["beats.studiobuds", "beats.earphones", "earbuds"],
            leftCandidates: ["beats.studiobuds.left", "earbud.left"],
            rightCandidates: ["beats.studiobuds.right", "earbud.right"],
            caseCandidates: ["beats.studiobuds.chargingcase", "beats.studiobuds.chargingcase.fill", "earbuds.case"]
        ),
        Self(
            matchTerms: ["beats solo buds", "beats solobuds"],
            rowCandidates: ["beats.solobuds", "beats.earphones", "earbuds"],
            deviceCandidates: ["beats.solobuds", "beats.earphones", "earbuds"],
            leftCandidates: ["beats.solobuds.left", "earbud.left"],
            rightCandidates: ["beats.solobuds.right", "earbud.right"],
            caseCandidates: ["beats.solobuds.chargingcase", "beats.solobuds.chargingcase.fill", "earbuds.case"]
        ),
        Self(
            matchTerms: ["beats powerbeats pro 2", "beats powerbeatspro 2"],
            rowCandidates: ["beats.powerbeats.pro.2", "beats.powerbeats.pro", "beats.powerbeats", "beats.earphones"],
            deviceCandidates: ["beats.powerbeats.pro.2", "beats.powerbeats.pro", "beats.powerbeats", "beats.earphones"],
            leftCandidates: ["beats.powerbeats.pro.2.left", "beats.powerbeats.pro.left", "earbud.left"],
            rightCandidates: ["beats.powerbeats.pro.2.right", "beats.powerbeats.pro.right", "earbud.right"],
            caseCandidates: ["beats.powerbeats.pro.2.chargingcase", "beats.powerbeats.pro.2.chargingcase.fill", "beats.powerbeats.pro.chargingcase", "earbuds.case"]
        ),
        Self(
            matchTerms: ["beats powerbeats pro", "beats powerbeatspro"],
            rowCandidates: ["beats.powerbeats.pro", "beats.powerbeats", "beats.earphones"],
            deviceCandidates: ["beats.powerbeats.pro", "beats.powerbeats", "beats.earphones"],
            leftCandidates: ["beats.powerbeats.pro.left", "earbud.left"],
            rightCandidates: ["beats.powerbeats.pro.right", "earbud.right"],
            caseCandidates: ["beats.powerbeats.pro.chargingcase", "beats.powerbeats.pro.chargingcase.fill", "earbuds.case"]
        ),
        Self(
            matchTerms: ["beats powerbeats3", "beats powerbeats 3"],
            rowCandidates: ["beats.powerbeats3", "beats.powerbeats", "beats.earphones"],
            deviceCandidates: ["beats.powerbeats3", "beats.powerbeats", "beats.earphones"],
            leftCandidates: ["beats.powerbeats3.left", "earbud.left"],
            rightCandidates: ["beats.powerbeats3.right", "earbud.right"]
        ),
        Self(
            matchTerms: ["beats powerbeats"],
            rowCandidates: ["beats.powerbeats", "beats.earphones"],
            deviceCandidates: ["beats.powerbeats", "beats.earphones"],
            leftCandidates: ["beats.powerbeats.left", "earbud.left"],
            rightCandidates: ["beats.powerbeats.right", "earbud.right"]
        ),
        Self(
            matchTerms: ["beats headphone", "beats solo", "beats studio"],
            rowCandidates: ["beats.headphones", "headphones"],
            deviceCandidates: ["beats.headphones", "headphones"]
        ),
        Self(
            matchTerms: ["beats"],
            rowCandidates: ["beats.earphones", "earbuds"],
            deviceCandidates: ["beats.earphones", "earbuds"],
            leftCandidates: ["earbud.left"],
            rightCandidates: ["earbud.right"]
        ),
    ]
}

private extension Array where Element == String {
    nonisolated func deduplicatedPreservingOrder() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

nonisolated struct BluetoothBatteryLevel: Codable, Equatable, Identifiable, Sendable {
    var role: BluetoothBatteryRole
    var percentage: Double
    var isCharging: Bool

    var id: BluetoothBatteryRole { role }

    init(role: BluetoothBatteryRole, percentage: Double, isCharging: Bool = false) {
        self.role = role
        self.percentage = min(max(percentage, 0), 1)
        self.isCharging = isCharging
    }

    static func parsed(role: BluetoothBatteryRole, value: String?) -> Self? {
        guard let value else {
            return nil
        }

        let digits = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
        guard let number = Double(digits) else {
            return nil
        }

        return Self(role: role, percentage: number / 100)
    }

    static func appleHIDDevice(
        percentage: Double,
        supportsExtendedBatteryState: Bool,
        statusFlags: Int?
    ) -> Self {
        Self(
            role: .device,
            percentage: percentage / 100,
            isCharging: supportsExtendedBatteryState && statusFlags == AppleHIDBatteryStatusFlags.charging
        )
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case percentage
        case isCharging
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(BluetoothBatteryRole.self, forKey: .role)
        percentage = min(max(try container.decode(Double.self, forKey: .percentage), 0), 1)
        isCharging = try container.decodeIfPresent(Bool.self, forKey: .isCharging) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(percentage, forKey: .percentage)
        try container.encode(isCharging, forKey: .isCharging)
    }

    private enum AppleHIDBatteryStatusFlags {
        static let charging = 3
    }
}

nonisolated enum BluetoothBatteryAlertSeverity: String, Codable, Sendable {
    case low
    case critical

    static func severity(for percentage: Double) -> Self? {
        if percentage <= 0.1 {
            return .critical
        }

        if percentage <= 0.2 {
            return .low
        }

        return nil
    }
}

nonisolated struct BluetoothBatteryAlert: Equatable, Hashable, Identifiable, Sendable {
    var deviceID: String
    var deviceName: String
    var category: BluetoothDeviceCategory
    var role: BluetoothBatteryRole
    var percentage: Double
    var severity: BluetoothBatteryAlertSeverity
    var isConnected: Bool

    var id: String {
        [deviceID, role.rawValue, severity.rawValue].joined(separator: ":")
    }

    #if DEBUG
    static let previewAirPodsProLeftCritical = BluetoothBatteryAlert(
        deviceID: "debug-airpods-pro",
        deviceName: "AirPods Pro",
        category: .headphones,
        role: .left,
        percentage: 0.09,
        severity: .critical,
        isConnected: true
    )
    #endif

    static func active(devices: [BluetoothDevice]) -> [BluetoothBatteryAlert] {
        devices
            .flatMap(\.lowBatteryAlerts)
            .sorted { lhs, rhs in
                if lhs.severity != rhs.severity {
                    return lhs.severity.sortIndex < rhs.severity.sortIndex
                }

                if lhs.percentage != rhs.percentage {
                    return lhs.percentage < rhs.percentage
                }

                if lhs.isConnected != rhs.isConnected {
                    return lhs.isConnected
                }

                if lhs.deviceName != rhs.deviceName {
                    return lhs.deviceName.localizedStandardCompare(rhs.deviceName) == .orderedAscending
                }

                return lhs.role.sortIndex < rhs.role.sortIndex
            }
    }
}

extension BluetoothBatteryAlert {
    nonisolated static func == (lhs: BluetoothBatteryAlert, rhs: BluetoothBatteryAlert) -> Bool {
        lhs.deviceID == rhs.deviceID &&
            lhs.role == rhs.role &&
            lhs.severity == rhs.severity
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(deviceID)
        hasher.combine(role)
        hasher.combine(severity)
    }
}

extension BluetoothBatteryAlertSeverity {
    nonisolated fileprivate var sortIndex: Int {
        switch self {
        case .critical:
            0
        case .low:
            1
        }
    }
}

extension BluetoothBatteryRole {
    nonisolated fileprivate var sortIndex: Int {
        switch self {
        case .left:
            0
        case .right:
            1
        case .case:
            2
        case .device:
            3
        }
    }
}

nonisolated struct BluetoothDevice: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var address: String?
    var category: BluetoothDeviceCategory
    var connectionState: BluetoothDeviceConnectionState
    var batteryLevels: [BluetoothBatteryLevel]

    init(
        id: String,
        name: String,
        address: String? = nil,
        category: BluetoothDeviceCategory = .unknown,
        connectionState: BluetoothDeviceConnectionState = .disconnected,
        batteryLevels: [BluetoothBatteryLevel] = []
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.category = category
        self.connectionState = connectionState
        self.batteryLevels = BluetoothDevice.sortedBatteryLevels(batteryLevels)
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var supportsConnectionAction: Bool {
        address != nil
    }

    var hasBattery: Bool {
        !batteryLevels.isEmpty
    }

    var lowBatteryAlerts: [BluetoothBatteryAlert] {
        batteryLevels.compactMap { level in
            guard
                !level.isCharging,
                let severity = BluetoothBatteryAlertSeverity.severity(for: level.percentage)
            else {
                return nil
            }

            return BluetoothBatteryAlert(
                deviceID: id,
                deviceName: name,
                category: category,
                role: level.role,
                percentage: level.percentage,
                severity: severity,
                isConnected: isConnected
            )
        }
    }

    func merged(with other: BluetoothDevice) -> BluetoothDevice {
        BluetoothDevice(
            id: id,
            name: preferredName(name, other.name),
            address: address ?? other.address,
            category: category == .unknown ? other.category : category,
            connectionState: connectionState == .connected || other.connectionState == .connected
                ? .connected
                : .disconnected,
            batteryLevels: other.batteryLevels.isEmpty ? batteryLevels : other.batteryLevels
        )
    }

    static func normalizedAddress(_ address: String?) -> String? {
        guard let address else {
            return nil
        }

        let normalized = address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: ":")
        return normalized.isEmpty ? nil : normalized
    }

    static func stableID(address: String?, name: String) -> String {
        normalizedAddress(address) ?? name.lowercased()
    }

    private static func sortedBatteryLevels(_ levels: [BluetoothBatteryLevel]) -> [BluetoothBatteryLevel] {
        let order: [BluetoothBatteryRole: Int] = [
            .left: 0,
            .right: 1,
            .case: 2,
            .device: 3,
        ]

        return levels.sorted {
            (order[$0.role] ?? Int.max, $0.role.rawValue) < (order[$1.role] ?? Int.max, $1.role.rawValue)
        }
    }

    private func preferredName(_ lhs: String, _ rhs: String) -> String {
        if lhs == id || lhs == address {
            return rhs
        }

        return lhs.isEmpty ? rhs : lhs
    }
}

nonisolated struct BluetoothDeviceSnapshot: Equatable, Sendable {
    var devices: [BluetoothDevice]
    var capturedAt: Date
    var errorMessage: String?

    static let empty = BluetoothDeviceSnapshot(devices: [], capturedAt: .distantPast, errorMessage: nil)
}
