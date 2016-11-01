//
//  Pesevere.swift
//  Pesevere
//
//  Created by Thomas Visser and Lars Lockefeer on 02/10/2016.
//  Copyright © 2016 Locke & Fisher. All rights reserved.
//

/// The strategy by which to delay retries
public indirect enum DelayStrategy {
    /// A strategy for a constant amount of delay
    /// between retries. Has the time interval as
    /// associated value
    case constant(TimeInterval)

    /// A strategy for a linear amount of delay
    /// between retries. Has the multiplier as
    /// associated value
    case linear(Double)

    /// An exponential backoff strategy
    /// Has the slot time `t` as associated value
    ///
    /// The first retry will take place either
    /// immediately or after `t`, chosen at random
    ///
    /// The second retry will take place either
    /// immediately or after `t`, `2t` or `3t`,
    /// chosen at random
    ///
    /// The nth retry, will take place at time
    /// `k · t`, where k is a random integer
    /// between 0 and 2^n − 1
    ///
    /// See: https://en.wikipedia.org/wiki/Exponential_backoff
    case exponentialBackoff(TimeInterval)

    /// A strategy that adds a random fuziness
    /// to another delay strategy
    case fuzzy(Double, DelayStrategy)

    /// A custom strategy, for you to define
    case custom((Int) -> TimeInterval)

    /// - parameter retry: The sequence number of the next retry, 1-based
    /// - returns: The number of seconds until the next retry
    internal func secondsUntilNextRetry(retry: Int) -> TimeInterval {
        switch self {
        case let .constant(delay):
            return delay
        case let .linear(multiplier):
            return multiplier * Double(retry)
        case let .exponentialBackoff(base):
            switch retry {
            case 1:
                return [0, base].randomElement!
            case 2:
                return [0, base, 2*base, 3*base].randomElement!
            default:
                // XXX: This should work for any (reasonable) number of retries
                let slot = min(retry, 32)
                let k = Random.generate(withUpperBound: pow(2.0, Double(slot)) - 1)
                return k * base
            }
        case let .fuzzy(fuziness, timing):
            let normalizedFuziness = ((Random.generate() * (2 * fuziness)) - fuziness) + 1.0
            return normalizedFuziness * timing.secondsUntilNextRetry(retry: retry)
        case let .custom(f):
            return f(retry)
        }
    }
}

/// A RetryPolicy describes a policy for Persevere by
/// which to retry failed operations
public struct RetryPolicy {
    /// The strategy by which to delay retries
    let delayStrategy: DelayStrategy
    fileprivate var maxRetries: Int

    /// Initialize a RetryPolicy
    /// - parameter delayStrategy: The delay strategy
    /// - parameter maxRetries: The maximum number of retries
    public init(delayStrategy: DelayStrategy, maxRetries: Int) {
        self.delayStrategy = delayStrategy
        self.maxRetries = maxRetries
    }
}

public protocol RetryableResult {
    var error: Error? { get }
}

public typealias Retryable<R: RetryableResult> = ((R) -> ()) -> ()

public class Persevere {

    private let policy: RetryPolicy
    private let executor = Executor()

    fileprivate init(policy: RetryPolicy) {
        self.policy = policy
    }

    /// Configure a `Persevere` instance
    /// with a retry policy
    /// - parameter policy: The policy
    ///
    /// - returns: A configured `Persevere` instance
    public static func with(policy: RetryPolicy) -> Persevere  {
        return Persevere(policy: policy)
    }

    /// Let this `Persevere` instance perform a
    /// retryable task
    ///
    /// The `onNext` closure will be called whenever
    /// the task succeeds, or as soon as the maximum
    /// number of retries has been reached
    ///
    /// - parameter retryable: The retryable task to perform
    /// - parameter result: Closure to execute on completion
    public func at<R: RetryableResult>(retryable: @escaping Retryable<R>, onNext: @escaping (R) -> ()) {
        executor.execute(context: RetryContext(policy: self.policy), retryable: retryable, onNext: onNext)
    }
}

fileprivate class Executor {

    private let queue = DispatchQueue(label: "com.lockeandfisher.perservere.executor")

    fileprivate func execute<R: RetryableResult>(context: RetryContext, retryable: @escaping Retryable<R>, onNext: @escaping (R) -> ()) {
        retryable { res in
            queue.sync {
                guard let _ = res.error else {
                    onNext(res)
                    return
                }

                if context.retriesLeft {
                    let deadline = DispatchTime.now() + DispatchTimeInterval(seconds: context.policy.delayStrategy.secondsUntilNextRetry(retry: context.nextTry))
                    context.queue.asyncAfter(deadline: deadline, execute: {
                        self.execute(context: context.next, retryable: retryable, onNext: onNext)
                    })
                } else {
                    onNext(res)
                }
            }
        }
    }
}

fileprivate struct RetryContext {
    let queue: DispatchQueue
    let policy: RetryPolicy
    var currentTry: Int = 0

    var nextTry: Int {
        return currentTry + 1
    }

    var retriesLeft: Bool {
        return currentTry < policy.maxRetries
    }

    var next: RetryContext {
        return RetryContext(policy: policy, currentTry: currentTry + 1)
    }

    init(policy: RetryPolicy, queue: DispatchQueue = DispatchQueue.global()) {
        self.policy = policy
        self.queue = queue
    }

    private init(policy: RetryPolicy, currentTry: Int, queue: DispatchQueue = DispatchQueue.global()) {
        self.policy = policy
        self.queue = queue
        self.currentTry = currentTry
    }
}

fileprivate extension Array {
    var randomElement: Element? {
        guard count > 0 else {
            return  nil
        }
        return self[Random.generate(withUpperBound: count)]
    }
}

fileprivate extension DispatchTimeInterval {
    init(seconds: TimeInterval) {
        // Note that we support delays of at most (2^32/1000)/3600 = 1193 hours
        self = .milliseconds(Int(round(seconds * Double(1000))))
    }
}

internal struct Random {
    private static func within(range: ClosedRange<Double>) -> Double {
        return (range.upperBound - range.lowerBound) * Double(Double(arc4random()) / Double(UInt32.max)) + range.lowerBound
    }

    static func generate(withUpperBound u: Double = 1.0) -> Double {
        return Random.within(range: 0.0...u)
    }

    static func generate(withUpperBound u: Int) -> Int {
        return Int(arc4random_uniform(UInt32(u)))
    }
}
