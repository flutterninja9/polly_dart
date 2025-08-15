---
sidebar_position: 4
---

# Outcome

The `Outcome<T>` class represents the result of a resilience pipeline execution, containing either a successful result or exception information.

## Overview

The Outcome class provides a type-safe way to handle both successful and failed operations. It encapsulates the result value, exception details, and provides utility methods for outcome analysis.

```dart
class Outcome<T> {
  const Outcome.success(T result);
  const Outcome.failure(Exception exception);
  
  bool get hasResult;
  bool get hasException;
  T get result;
  Exception get exception;
  
  T getResultOrThrow();
  T getResultOrDefault(T defaultValue);
  T? getResultOrNull();
  
  Outcome<U> map<U>(U Function(T) mapper);
  Outcome<U> flatMap<U>(Outcome<U> Function(T) mapper);
  Outcome<T> recover(T Function(Exception) recovery);
  Outcome<T> onSuccess(void Function(T) action);
  Outcome<T> onFailure(void Function(Exception) action);
}
```

## Constructors

### Outcome.success(T result)

Creates a successful outcome with the specified result.

**Parameters:**
- `result` - The successful result value

```dart
final outcome = Outcome.success('Hello World');
print(outcome.hasResult); // true
print(outcome.result); // Hello World
```

### Outcome.failure(Exception exception)

Creates a failed outcome with the specified exception.

**Parameters:**
- `exception` - The exception that occurred

```dart
final outcome = Outcome.failure(TimeoutException('Request timed out'));
print(outcome.hasException); // true
print(outcome.exception); // TimeoutException
```

## Properties

### hasResult

Gets a value indicating whether the outcome contains a successful result.

**Type:** `bool`

```dart
if (outcome.hasResult) {
  print('Operation succeeded: ${outcome.result}');
}
```

### hasException

Gets a value indicating whether the outcome contains an exception.

**Type:** `bool`

```dart
if (outcome.hasException) {
  print('Operation failed: ${outcome.exception}');
}
```

### result

Gets the successful result value. Throws if the outcome is a failure.

**Type:** `T`

**Throws:** `StateError` if the outcome is a failure

```dart
try {
  final value = outcome.result;
  print('Success: $value');
} on StateError {
  print('Cannot access result on failed outcome');
}
```

### exception

Gets the exception. Throws if the outcome is successful.

**Type:** `Exception`

**Throws:** `StateError` if the outcome is successful

```dart
try {
  final error = outcome.exception;
  print('Error: $error');
} on StateError {
  print('Cannot access exception on successful outcome');
}
```

## Methods

### getResultOrThrow()

Gets the result value or throws the contained exception.

**Returns:** `T` - The result value

**Throws:** The contained exception if the outcome is a failure

```dart
try {
  final value = outcome.getResultOrThrow();
  print('Success: $value');
} catch (e) {
  print('Failed: $e');
}
```

### getResultOrDefault(T defaultValue)

Gets the result value or returns the specified default value if the outcome is a failure.

**Parameters:**
- `defaultValue` - The value to return if the outcome is a failure

**Returns:** `T` - The result value or default value

```dart
final value = outcome.getResultOrDefault('default');
print('Value: $value'); // Returns result or 'default'
```

### getResultOrNull()

Gets the result value or returns null if the outcome is a failure.

**Returns:** `T?` - The result value or null

```dart
final value = outcome.getResultOrNull();
if (value != null) {
  print('Success: $value');
} else {
  print('Operation failed');
}
```

### map&lt;U&gt;(U Function(T) mapper)

Transforms the successful result using the specified mapper function. If the outcome is a failure, returns a new failure outcome with the same exception.

**Parameters:**
- `mapper` - Function to transform the result

**Returns:** `Outcome<U>` - New outcome with transformed result

```dart
final stringOutcome = Outcome.success(42);
final doubledOutcome = stringOutcome.map((value) => value * 2);
print(doubledOutcome.result); // 84

final lengthOutcome = stringOutcome.map((value) => value.toString().length);
print(lengthOutcome.result); // 2
```

### flatMap&lt;U&gt;(Outcome&lt;U&gt; Function(T) mapper)

Transforms the successful result using a function that returns an Outcome. Useful for chaining operations that might fail.

**Parameters:**
- `mapper` - Function that transforms the result to another Outcome

**Returns:** `Outcome<U>` - The outcome returned by the mapper function

```dart
final numberOutcome = Outcome.success('42');
final parsedOutcome = numberOutcome.flatMap((str) {
  try {
    return Outcome.success(int.parse(str));
  } catch (e) {
    return Outcome.failure(FormatException('Invalid number: $str'));
  }
});
```

### recover(T Function(Exception) recovery)

Recovers from a failure by providing an alternative result. If the outcome is successful, returns the original outcome.

**Parameters:**
- `recovery` - Function to provide alternative result

**Returns:** `Outcome<T>` - Recovered outcome or original if successful

```dart
final failedOutcome = Outcome.failure(TimeoutException('Timeout'));
final recoveredOutcome = failedOutcome.recover((exception) => 'fallback-value');
print(recoveredOutcome.result); // 'fallback-value'
```

### onSuccess(void Function(T) action)

Executes the specified action if the outcome is successful.

**Parameters:**
- `action` - Action to execute with the result

**Returns:** `Outcome<T>` - The original outcome for chaining

```dart
outcome
  .onSuccess((value) => print('Success: $value'))
  .onFailure((error) => print('Error: $error'));
```

### onFailure(void Function(Exception) action)

Executes the specified action if the outcome is a failure.

**Parameters:**
- `action` - Action to execute with the exception

**Returns:** `Outcome<T>` - The original outcome for chaining

```dart
outcome
  .onSuccess((value) => print('Success: $value'))
  .onFailure((error) => print('Error: $error'));
```

## Usage Examples

### Basic Outcome Handling

```dart
Future<Outcome<String>> fetchData() async {
  try {
    final data = await apiCall();
    return Outcome.success(data);
  } catch (e) {
    return Outcome.failure(e as Exception);
  }
}

final outcome = await fetchData();
if (outcome.hasResult) {
  print('Data: ${outcome.result}');
} else {
  print('Error: ${outcome.exception}');
}
```

### Pipeline Execution with Outcomes

```dart
final outcome = await pipeline.executeAndCapture<String>((context) async {
  return await fetchUserData(userId);
});

final result = outcome.getResultOrDefault('Guest User');
print('User: $result');
```

### Chaining Operations

```dart
final outcome = await pipeline.executeAndCapture<String>((context) async {
  return await fetchUserData(userId);
});

final processedOutcome = outcome
  .map((userData) => userData.toUpperCase())
  .onSuccess((data) => print('Processed: $data'))
  .onFailure((error) => logger.error('Failed to fetch user data', error));
```

### Complex Transformations

```dart
final userIdOutcome = Outcome.success('12345');

final userDataOutcome = await userIdOutcome.flatMap((userId) async {
  try {
    final userData = await fetchUserData(userId);
    return Outcome.success(userData);
  } catch (e) {
    return Outcome.failure(e as Exception);
  }
});

final finalResult = userDataOutcome
  .map((userData) => userData.displayName)
  .recover((error) => 'Unknown User')
  .getResultOrThrow();
```

### Error Recovery Patterns

```dart
final outcome = await pipeline.executeAndCapture<List<String>>((context) async {
  return await fetchDataList();
});

final safeResult = outcome
  .recover((error) {
    // Return cached data or empty list
    return getCachedData() ?? <String>[];
  })
  .map((list) => list.where((item) => item.isNotEmpty).toList())
  .getResultOrDefault(<String>[]);
```

### Conditional Processing

```dart
final outcome = await pipeline.executeAndCapture<int>((context) async {
  return await calculateValue();
});

final processedValue = outcome
  .onSuccess((value) {
    if (value > 100) {
      logger.warn('High value detected: $value');
    }
  })
  .onFailure((error) {
    metrics.incrementCounter('calculation_failures');
  })
  .map((value) => value.clamp(0, 100))
  .getResultOrDefault(0);
```

## Best Practices

### Always Handle Both Cases

```dart
// Good
if (outcome.hasResult) {
  handleSuccess(outcome.result);
} else {
  handleFailure(outcome.exception);
}

// Or use methods
outcome
  .onSuccess(handleSuccess)
  .onFailure(handleFailure);
```

### Use Safe Accessors

```dart
// Good - Safe access
final value = outcome.getResultOrDefault('fallback');

// Avoid - Can throw
final value = outcome.result; // Throws if failed
```

### Chain Operations Safely

```dart
final result = outcome
  .map(transformData)
  .recover(provideDefault)
  .getResultOrThrow();
```
