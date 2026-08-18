import XCTest
@testable import DesktopNumber

final class PmsetParsingTests: XCTestCase {
    func testParseSleepDisabled() {
        let output = """
        SleepDisabled\t1
        sleep                0
        """
        XCTAssertTrue(PmsetParser.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabledWithDoubleTabAlignment() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         sleep                0
        """
        XCTAssertTrue(PmsetParser.parseSleepDisabled(from: output))
    }

    func testParseSleepDisabledReturnsFalseForZero() {
        let output = " SleepDisabled\t\t0\n"
        XCTAssertFalse(PmsetParser.parseSleepDisabled(from: output))
    }

    func testParseCustomProfiles() {
        let output = """
        AC Power:
         sleep                0
         tcpkeepalive         1
        Battery Power:
         sleep                1
         tcpkeepalive         0
        """
        let profiles = PmsetParser.parseCustomProfiles(from: output)
        XCTAssertEqual(profiles.ac.sleepMinutes, 0)
        XCTAssertEqual(profiles.ac.tcpKeepAlive, true)
        XCTAssertEqual(profiles.battery.sleepMinutes, 1)
        XCTAssertEqual(profiles.battery.tcpKeepAlive, false)
    }

    func testOfficeReadyOnACWithSleepZero() {
        let status = OfficePowerStatus.evaluate(isOnACPower: true, acSleepMinutes: 0)
        XCTAssertTrue(status.preventSleepWhenDisplayOff)
        XCTAssertTrue(status.isOfficeReady)
    }

    func testOfficeNotReadyOnBatteryEvenWithSleepZero() {
        let status = OfficePowerStatus.evaluate(isOnACPower: false, acSleepMinutes: 0)
        XCTAssertFalse(status.isOfficeReady)
    }
}
