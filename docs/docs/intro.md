---
sidebar_position: 1
---

# Welcome to Polly Dart

**Polly Dart** is a comprehensive resilience and transient-fault-handling library for Dart applications. Inspired by the .NET [Polly library](https://github.com/App-vNext/Polly), it provides developers with powerful tools to handle failures gracefully and build robust applications.

## What is Resilience?

In distributed systems and modern applications, failures are inevitable. Network calls timeout, services become unavailable, and resources get exhausted. **Resilience** is the ability of your application to handle these failures gracefully, recover quickly, and continue providing value to users.

Polly Dart helps you implement resilience patterns without cluttering your business logic with error-handling boilerplate code.

## Why Polly Dart?

### 🎯 **Purpose-Built for Resilience**
Unlike generic error handling, Polly Dart provides specialized strategies designed for specific failure scenarios:
- **Transient failures** → Retry with intelligent backoff
- **Cascading failures** → Circuit Breaker protection  
- **Slow operations** → Timeout controls
- **Service degradation** → Fallback mechanisms
- **Resource overload** → Rate limiting and hedging

### 🔧 **Developer Experience**
```dart
// Before: Complex error handling scattered throughout your code
try {
  result = await apiCall();
} catch (e) {
  if (isTransientError(e)) {
    await Future.delayed(Duration(seconds: 1));
    try {
      result = await apiCall();
    } catch (e2) {
      // More nested error handling...
    }
  }
}

// After: Clean, declarative resilience policies
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 10))
    .addFallback(FallbackStrategyOptions.withValue('default'))
    .build();

final result = await pipeline.execute(() => apiCall());
```

### 🏗️ **Composable Architecture**
Strategies can be combined in any order to create sophisticated resilience pipelines:

```mermaid
graph LR
    A[Your Code] --> B[Retry Strategy]
    B --> C[Circuit Breaker]
    C --> D[Timeout Strategy]
    D --> E[Fallback Strategy]
    E --> F[Actual Operation]
```

## Core Concepts

### 🔄 **Reactive Strategies**
Handle failures after they occur:
- **[Retry](./strategies/retry)** - Automatically retry failed operations
- **[Circuit Breaker](./strategies/circuit-breaker)** - Prevent cascading failures
- **[Fallback](./strategies/fallback)** - Provide alternative responses
- **[Hedging](./strategies/hedging)** - Execute parallel attempts

### ⚡ **Proactive Strategies** 
Prevent failures before they impact your system:
- **[Timeout](./strategies/timeout)** - Cancel long-running operations
- **[Rate Limiter](./strategies/rate-limiter)** - Control operation rate and concurrency

## Quick Start

Get up and running in minutes:

### 1. Installation
```yaml
dependencies:
  polly_dart: ^0.1.0
```

### 2. Basic Usage
```dart
import 'package:polly_dart/polly_dart.dart';

// Create a resilience pipeline
final pipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 10))
    .build();

// Execute with resilience
final result = await pipeline.execute((context) async {
  return await httpClient.get('https://api.example.com/data');
});
```

### 3. Real-World Example
```dart
// HTTP client with comprehensive resilience
final httpPipeline = ResiliencePipelineBuilder()
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 3,
      delay: Duration(seconds: 1),
      backoffType: DelayBackoffType.exponential,
      shouldHandle: (outcome) => outcome.hasException && 
                                 isTransientHttpError(outcome.exception),
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.5,
      samplingDuration: Duration(seconds: 30),
      minimumThroughput: 10,
      breakDuration: Duration(seconds: 5),
    ))
    .addTimeout(Duration(seconds: 30))
    .addFallback(FallbackStrategyOptions(
      fallbackAction: (args) async => Outcome.fromResult(getCachedData()),
      shouldHandle: (outcome) => true,
    ))
    .build();

// Use it
final data = await httpPipeline.execute((context) async {
  final response = await httpClient.get('https://api.example.com/critical-data');
  return processResponse(response);
});
```

## What's Next?

<div className="row">
  <div className="col col--6">
    <div className="card">
      <div className="card__header">
        <h3>🚀 Get Started</h3>
      </div>
      <div className="card__body">
        <p>New to Polly Dart? Start with our step-by-step guide.</p>
        <a href="./getting-started/installation" className="button button--primary">
          Installation Guide
        </a>
      </div>
    </div>
  </div>
  <div className="col col--6">
    <div className="card">
      <div className="card__header">
        <h3>📚 Learn Strategies</h3>
      </div>
      <div className="card__body">
        <p>Explore the resilience strategies and when to use them.</p>
        <a href="./strategies/overview" className="button button--primary">
          Resilience Strategies
        </a>
      </div>
    </div>
  </div>
</div>

<div className="row margin-top--lg">
  <div className="col col--6">
    <div className="card">
      <div className="card__header">
        <h3>🔧 API Reference</h3>
      </div>
      <div className="card__body">
        <p>Complete API documentation with all classes and methods.</p>
        <a href="./api/resilience-pipeline" className="button button--primary">
          API Documentation
        </a>
      </div>
    </div>
  </div>
  <div className="col col--6">
    <div className="card">
      <div className="card__header">
        <h3>💡 Examples</h3>
      </div>
      <div className="card__body">
        <p>Real-world examples and use cases.</p>
        <a href="./examples/http-client" className="button button--primary">
          View Examples
        </a>
      </div>
    </div>
  </div>
</div>

## Community & Support

- 🐛 **Found a bug?** [Report it on GitHub](https://github.com/flutterninja9/polly_dart/issues)
- 💡 **Have an idea?** [Start a discussion](https://github.com/flutterninja9/polly_dart/discussions)
- 📦 **Check out the package** [on pub.dev](https://pub.dev/packages/polly_dart)

---

*Polly Dart is inspired by the .NET Polly library and adapted for the Dart ecosystem. Special thanks to the Polly community for pioneering resilience patterns.*
