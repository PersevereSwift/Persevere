//
//  PersevereRxSwiftTests.swift
//  PersevereRxSwiftTests
//
//  Created by Thomas Visser on 05/11/16.
//  Copyright © 2016 Locke & Fisher. All rights reserved.
//

import XCTest
import RxSwift
import RxBlocking
import Foundation
import Persevere

@testable import PersevereRxSwift

class PersevereRxSwiftTests: XCTestCase {
    
    enum TestError: Error {
        case anError
    }
    
    func testRetry() {
        
        let observable = Observable<Int>.of(1, 2, 3)
            .concat(Observable.error(TestError.anError))
        
        let policy = RetryPolicy(
            delayStrategy: .constant(0),
            maxRetries: 1
        )
        
        let array = try! observable.retry(with: policy).catchErrorJustReturn(0).toBlocking().toArray()
        
        XCTAssertEqual(array, [1, 2, 3, 1, 2, 3, 0])
    }
    
}
