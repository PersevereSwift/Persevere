//
//  PersevereTests.swift
//  PersevereTests
//
//  Created by Thomas Visser and Lars Lockefeer on 02/10/2016.
//  Copyright © 2016 Locke & Fisher. All rights reserved.
//

import XCTest
import Persevere

class RetryTests: XCTestCase {

    func testRetryWorks() {
        let policy = RetryPolicy(
            delayStrategy: .linear(0.001),
            maxRetries: 2
        )

        let e = expectation(description: "")

        let helper = RetryHelper(results: [
            TaskResult.error,
            TaskResult.error,
            TaskResult.success
            ])

        Persevere
            .with(policy: policy)
            .at(retryable: helper.task) { r in
                XCTAssertEqual(TaskResult.success, r)
                e.fulfill()
        }

        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testMaxCountReached() {
        let policy = RetryPolicy(
            delayStrategy: .linear(0.001),
            maxRetries: 1
        )

        let e = expectation(description: "")

        let helper = RetryHelper(results: [
            TaskResult.error,
            TaskResult.error,
            ])

        Persevere
            .with(policy: policy)
            .at(retryable: helper.task) { r in
                XCTAssertEqual(TaskResult.error, r)
                e.fulfill()
        }

        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testLinearDelayInterval() {
        let expectedDelay = 0.01
        let policy = RetryPolicy(
            delayStrategy: .linear(expectedDelay),
            maxRetries: 1
        )

        let e = expectation(description: "")

        let helper = RetryHelper(results: [
            TaskResult.error,
            TaskResult.error
            ])

        let then = Date()

        Persevere
            .with(policy: policy)
            .at(retryable: helper.task) { r in
                XCTAssertEqual(TaskResult.error, r)
                e.fulfill()
        }

        self.waitForExpectations(timeout: 2, handler: nil)

        // It must have taken at least the expected amount of delay
        XCTAssert(then.timeIntervalSinceNow < -expectedDelay)
    }
}

enum TestError: Error {
    case unknown
}

enum TaskResult: RetryableResult {
    case success
    case error

    var error: Error? {
        switch self {
        case .success: return nil
        case .error: return TestError.unknown
        }
    }
}

extension TaskResult: Equatable {
    static func ==(lhs: TaskResult, rhs: TaskResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success): return true
        case (.error, .error): return true
        default: return false
        }
    }
}

class RetryHelper<R: RetryableResult> {

    let results: [R]
    var invocations = 0

    init(results: [R]) {
        self.results = results
    }

    var task: Retryable<R> {
        return { next in
            defer { self.invocations += 1 }
            next(self.results[self.invocations])
        }
    }
}
