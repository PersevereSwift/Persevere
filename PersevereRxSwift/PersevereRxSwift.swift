//
//  PersevereRxSwift.swift
//  Persevere
//
//  Created by Thomas Visser on 05/11/16.
//  Copyright © 2016 Locke & Fisher. All rights reserved.
//

import Foundation
import Persevere
import RxSwift

extension Event: RetryableResult {
    
}

extension ObservableType {
    
    func retry(with policy: RetryPolicy) -> Observable<E> {
        return Observable.create { observer in
            
            let disposables = CompositeDisposable()
            
            Persevere.with(policy: policy).at(retryable: { (emit: @escaping (Event<E>) -> ()) in
                let d = self.subscribe { event in
                    emit(event)
                }
                let _ = disposables.insert(d)
            }, onNext: { event in
                if !disposables.isDisposed {
                    observer.on(event)
                }
            })
            
            return disposables
        }
    }
    
}
