import Foundation

@main
struct CommuteFailsafeMain {
    static func main() {
        CommuteFailsafeMain.run()
    }

    static func run() {
        let arguments = CommandLine.arguments.dropFirst()
        guard let config = CommuteFailsafeConfiguration(arguments: Array(arguments)) else {
            fputs("CommuteFailsafe: invalid arguments\n", stderr)
            exit(2)
        }

        let leaseURL = URL(fileURLWithPath: config.leasePath)
        let store = CommuteModeStateStore(customLeaseURL: leaseURL)
        let powerClient = PmsetPowerManagementClient()
        let powerMonitor = PowerStatusMonitor()
        let policy = CommuteFailsafePolicy(
            batteryThresholdPercent: config.batteryThresholdPercent,
            pollIntervalSeconds: config.pollIntervalSeconds
        )

        while true {
            let now = Date()
            let thermalState = powerMonitor.currentThermalState()
            if let reason = policy.shouldStop(
                ownerPID: config.ownerPID,
                deadline: config.deadline,
                now: now,
                isOnBattery: powerMonitor.isOnBatteryPower(),
                batteryPercent: powerMonitor.batteryPercent(),
                thermalState: thermalState
            ) {
                disableCommuteMode(
                    store: store,
                    powerClient: powerClient,
                    leasePath: config.leasePath,
                    reason: reason
                )
                exit(0)
            }

            if let lease = store.loadLease(), !lease.isActive {
                exit(0)
            }

            Thread.sleep(forTimeInterval: policy.pollIntervalSeconds)
        }
    }

    private static func disableCommuteMode(
        store: CommuteModeStateStore,
        powerClient: PowerManagementClient,
        leasePath: String,
        reason: CommuteStopReason
    ) {
        if powerClient.hasPasswordlessPmsetAccess() {
            do {
                try powerClient.setSleepDisabled(false)
            } catch {
                fputs("CommuteFailsafe: failed to disable sleep: \(error.localizedDescription)\n", stderr)
            }
        }

        if let lease = store.loadLease() {
            var updatedLease = lease
            updatedLease.isActive = false
            updatedLease.lastStopReason = reason
            updatedLease.lastStopAt = Date()
            do {
                try store.saveLease(updatedLease)
            } catch {
                fputs("CommuteFailsafe: failed to save lease at \(leasePath)\n", stderr)
            }
        }
    }
}

struct CommuteFailsafeConfiguration {
    let leasePath: String
    let ownerPID: Int32
    let deadline: Date
    let batteryThresholdPercent: Int
    let pollIntervalSeconds: TimeInterval

    init?(arguments: [String]) {
        var leasePath: String?
        var ownerPID: Int32?
        var deadline: Date?
        var batteryThresholdPercent = 20
        var pollIntervalSeconds = 5.0

        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            switch flag {
            case "--lease-path":
                index += 1
                guard index < arguments.count else { return nil }
                leasePath = arguments[index]
            case "--owner-pid":
                index += 1
                guard index < arguments.count, let value = Int32(arguments[index]) else { return nil }
                ownerPID = value
            case "--deadline":
                index += 1
                guard index < arguments.count else { return nil }
                let formatter = ISO8601DateFormatter()
                guard let parsed = formatter.date(from: arguments[index]) else { return nil }
                deadline = parsed
            case "--battery-threshold":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]) else { return nil }
                batteryThresholdPercent = value
            case "--poll-interval":
                index += 1
                guard index < arguments.count, let value = Double(arguments[index]) else { return nil }
                pollIntervalSeconds = value
            default:
                return nil
            }
            index += 1
        }

        guard let leasePath, let ownerPID, let deadline else { return nil }
        self.leasePath = leasePath
        self.ownerPID = ownerPID
        self.deadline = deadline
        self.batteryThresholdPercent = batteryThresholdPercent
        self.pollIntervalSeconds = pollIntervalSeconds
    }
}
