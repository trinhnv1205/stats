//
//  Sensors.swift
//  Tests
//
//  Created by Claude on 14/06/2026.
//  Using Swift 5.0.
//  Running on macOS 12.0.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import Sensors

class Sensors: XCTestCase {
    // MARK: - ratio

    func testRatioWithinWindow() throws {
        let window = (min: 40.0, max: 75.0)
        XCTAssertEqual(FanCurve.ratio(temperature: 40, window: window), 0, accuracy: 1e-9)
        XCTAssertEqual(FanCurve.ratio(temperature: 75, window: window), 1, accuracy: 1e-9)
        XCTAssertEqual(FanCurve.ratio(temperature: 57.5, window: window), 0.5, accuracy: 1e-9)
    }

    func testRatioClampsOutsideWindow() throws {
        let window = (min: 40.0, max: 75.0)
        XCTAssertEqual(FanCurve.ratio(temperature: 10, window: window), 0, accuracy: 1e-9)
        XCTAssertEqual(FanCurve.ratio(temperature: 200, window: window), 1, accuracy: 1e-9)
    }

    func testRatioDegenerateWindowIsZero() throws {
        // Guards against division by zero when min == max.
        XCTAssertEqual(FanCurve.ratio(temperature: 50, window: (min: 50, max: 50)), 0, accuracy: 1e-9)
    }

    // MARK: - target

    func testTargetInterpolation() throws {
        XCTAssertEqual(FanCurve.target(ratio: 0, minSpeed: 1200, maxSpeed: 4800), 1200, accuracy: 1e-9)
        XCTAssertEqual(FanCurve.target(ratio: 1, minSpeed: 1200, maxSpeed: 4800), 4800, accuracy: 1e-9)
        XCTAssertEqual(FanCurve.target(ratio: 0.5, minSpeed: 1200, maxSpeed: 4800), 3000, accuracy: 1e-9)
        XCTAssertEqual(FanCurve.target(ratio: 0.25, minSpeed: 1200, maxSpeed: 4800), 2100, accuracy: 1e-9)
    }

    // MARK: - smooth (EMA)

    func testSmoothMovesPartwayToTarget() throws {
        // alpha 0.35: 1000 + 0.35 * (2000 - 1000) = 1350
        XCTAssertEqual(FanCurve.smooth(previous: 1000, target: 2000, alpha: 0.35), 1350, accuracy: 1e-9)
    }

    func testSmoothIsStableAtTarget() throws {
        XCTAssertEqual(FanCurve.smooth(previous: 2000, target: 2000, alpha: 0.35), 2000, accuracy: 1e-9)
    }

    func testSmoothConvergesMonotonically() throws {
        var value = 1000.0
        var previous = value
        for _ in 0..<200 {
            value = FanCurve.smooth(previous: value, target: 3000, alpha: 0.35)
            XCTAssertGreaterThanOrEqual(value, previous) // never overshoots downward while rising
            XCTAssertLessThanOrEqual(value, 3000)        // and never exceeds the target
            previous = value
        }
        XCTAssertEqual(value, 3000, accuracy: 0.5)
    }

    // MARK: - round

    func testRoundToStep() throws {
        XCTAssertEqual(FanCurve.round(1234, step: 50), 1250)
        XCTAssertEqual(FanCurve.round(1224, step: 50), 1200)
        XCTAssertEqual(FanCurve.round(1225, step: 50), 1250) // halves round away from zero
        XCTAssertEqual(FanCurve.round(0, step: 50), 0)
        XCTAssertEqual(FanCurve.round(4799, step: 50), 4800)
    }

    // MARK: - deadband

    func testDeadbandIsFractionOfRange() throws {
        // 4% of (4800 - 1200) = 144, which is above the step floor.
        XCTAssertEqual(FanCurve.deadband(minSpeed: 1200, maxSpeed: 4800, fraction: 0.04, step: 50), 144)
    }

    func testDeadbandFlooredToStep() throws {
        // 4% of (1100 - 1000) = 4, floored up to one step.
        XCTAssertEqual(FanCurve.deadband(minSpeed: 1000, maxSpeed: 1100, fraction: 0.04, step: 50), 50)
    }

    // MARK: - shouldApply

    func testShouldApplyFirstWrite() throws {
        XCTAssertTrue(FanCurve.shouldApply(newValue: 1500, lastApplied: nil, deadband: 144))
    }

    func testShouldApplySuppressesSmallChange() throws {
        XCTAssertFalse(FanCurve.shouldApply(newValue: 1550, lastApplied: 1500, deadband: 144)) // 50 < 144
        XCTAssertFalse(FanCurve.shouldApply(newValue: 1500, lastApplied: 1500, deadband: 144)) // no change
    }

    func testShouldApplyAllowsLargeChange() throws {
        XCTAssertTrue(FanCurve.shouldApply(newValue: 1700, lastApplied: 1500, deadband: 144))  // 200 >= 144
        XCTAssertTrue(FanCurve.shouldApply(newValue: 1356, lastApplied: 1500, deadband: 144))  // 144 >= 144 (boundary)
    }
}
