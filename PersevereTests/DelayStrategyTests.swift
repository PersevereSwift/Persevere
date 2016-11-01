//
//  DelayStrategyTests.swift
//  Persevere
//
//  Created by Lars Lockefeer on 03/10/2016.
//  Copyright © 2016 Locke & Fisher. All rights reserved.
//

import XCTest
@testable import Persevere

class DelayStrategyTests: XCTestCase {
    func testConstantDelayStrategy() {
        let s = DelayStrategy.constant(1)
        XCTAssertEqual(s.delays(forNumberOfRetries: 3), [1.0, 1.0, 1.0])
    }

    func testLinearDelayStrategy() {
        let s = DelayStrategy.linear(2)
        XCTAssertEqual(s.delays(forNumberOfRetries: 3), [2, 4, 6])
    }

    func testExpBackoffStrategy() {
        let base: TimeInterval = 0.1
        let s = DelayStrategy.exponentialBackoff(base)
        let delays = s.delays(forNumberOfRetries: 100)

        for (i, v) in delays.enumerated() {
            let retry = i + 1
            switch retry {
            case 1: XCTAssertTrue(v == 0 || v == base)
            case 2: XCTAssertTrue(v == 0 || v == base || v == base*2 || v == base*3)
            default:
                XCTAssertGreaterThanOrEqual(v, 0)
                let slot = min(retry, 32)
                let upperK = pow(2.0, Double(slot)) - 1

                XCTAssertLessThanOrEqual(v, upperK * base)
            }
        }
    }

    func testFuzzyDelayStrategy() {
        let base = 1.0
        let fuziness = 0.5

        let s = DelayStrategy.constant(base)
        let fs = DelayStrategy.fuzzy(fuziness, s)

        let delays = fs.delays(forNumberOfRetries: 10)
        for delay in delays {
            print(delay)
            XCTAssertGreaterThanOrEqual(delay, base - fuziness)
            XCTAssertLessThanOrEqual(delay, base + fuziness)
        }
    }

    func testCustomDelayStrategy() {
        let s = DelayStrategy.custom({TimeInterval($0)})
        XCTAssertEqual(s.delays(forNumberOfRetries: 3), [1.0, 2.0, 3.0])
    }

    func testRandom() {
        for _ in 0...10000 {
            XCTAssertGreaterThanOrEqual(Random.generate(withUpperBound: Double(10)), Double(0))
            XCTAssertLessThanOrEqual(Random.generate(withUpperBound: Double(10)), Double(10))
        }
    }
}

private extension DelayStrategy {
    func delays(forNumberOfRetries n: Int) -> [TimeInterval] {
        return (1...n).map(secondsUntilNextRetry)
    }
}
