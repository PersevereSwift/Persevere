# Persevere
> “Ever tried. Ever failed. No Matter. Try again. Fail again. Fail better.” 

>  — Samuel Beckett, *Worstward Ho*

## Introduction

Some tasks always succeed. For the rest, Persevere is here to help with all your retrying needs.

## Features

* Define a constant delay interval between retries
* Define a delay interval linear to the number of retries
* Use exponential backoff
* Add fuziness to your delay interval
* Define a custom delay interval
* Define an upper bound on the number of retries

## Usage

```swift
let policy = RetryPolicy(
    delay: .linear(DispatchTimeInterval.seconds(1)),  // Wait for 1 second in between each retry
    maxRetries: 2  // Retry at most 2 times
)

Persevere
    .with(policy: policy)
    .at(retryable: { (next: (TaskResult) -> ()) in
        next(random(.success, .error))  // Randomly select success or error
    }) { result in
        // Result will be .success if selected within 2 times
        // Otherwise .error
    }
```

