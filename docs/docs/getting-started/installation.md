---
sidebar_position: 1
---

# Installation

Get Polly Dart up and running in your Dart or Flutter project in just a few steps.

## Requirements

- **Dart SDK**: 3.5.0 or higher
- **Flutter**: Compatible with all Flutter versions that support Dart 3.5.0+

## Adding Polly Dart to Your Project

### Using `dart pub add` (Recommended)

The easiest way to add Polly Dart to your project:

```bash
dart pub add polly_dart
```

For Flutter projects:
```bash
flutter pub add polly_dart
```

### Manual Installation

Alternatively, add Polly Dart manually to your `pubspec.yaml`:

```yaml title="pubspec.yaml"
dependencies:
  polly_dart: ^0.1.0
```

Then run:
```bash
dart pub get
# or for Flutter
flutter pub get
```

## Verify Installation

Create a simple test file to verify the installation:

```dart title="test_polly.dart"
import 'package:polly_dart/polly_dart.dart';

void main() async {
  // Create a simple pipeline
  final pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .build();
  
  // Test it works
  final result = await pipeline.execute((context) async {
    print('Executing operation...');
    return 'Hello, Polly Dart!';
  });
  
  print('Result: $result');
}
```

Run the test:
```bash
dart run test_polly.dart
```

You should see output like:
```
Executing operation...
Result: Hello, Polly Dart!
```

## Import Statement

After installation, import Polly Dart in your Dart files:

```dart
import 'package:polly_dart/polly_dart.dart';
```

This single import gives you access to all the core classes:
- `ResiliencePipelineBuilder`
- `ResiliencePipeline`
- `ResilienceContext`
- `Outcome`
- All strategy options classes

## Platform Compatibility

Polly Dart is designed to work across all Dart platforms:

| Platform | Support Status | Notes |
|----------|----------------|-------|
| **Flutter (Mobile)** | ✅ Full Support | iOS and Android |
| **Flutter (Web)** | ✅ Full Support | All strategies work |
| **Flutter (Desktop)** | ✅ Full Support | Windows, macOS, Linux |
| **Dart Server** | ✅ Full Support | All server environments |
| **Dart CLI** | ✅ Full Support | Command-line applications |

## Development Setup

If you're contributing to Polly Dart or want to run the examples:

### Clone the Repository
```bash
git clone https://github.com/flutterninja9/polly_dart.git
cd polly_dart
```

### Install Dependencies
```bash
dart pub get
```

### Run Tests
```bash
dart test
```

### Run Examples
```bash
dart run example/polly_dart_example.dart
```

## Next Steps

Now that you have Polly Dart installed, you're ready to:

1. **[📖 Quick Start](./quick-start)** - Build your first resilience pipeline
2. **[🧠 Learn Basic Concepts](./basic-concepts)** - Understand the core principles
3. **[🔄 Explore Strategies](../strategies/overview)** - Discover all available resilience strategies

## Troubleshooting

### Common Issues

**Issue**: `pub get` fails with dependency resolution error
- **Solution**: Ensure you're using Dart 3.5.0 or higher. Check with `dart --version`.

**Issue**: Import errors in IDE
- **Solution**: Run `dart pub get` and restart your IDE/editor.

**Issue**: "Package doesn't exist" error
- **Solution**: Verify you're connected to the internet and pub.dev is accessible.

### Getting Help

If you encounter issues:

1. Check the [GitHub Issues](https://github.com/flutterninja9/polly_dart/issues) for known problems
2. Search [GitHub Discussions](https://github.com/flutterninja9/polly_dart/discussions) for solutions
3. Create a new issue with:
   - Your Dart/Flutter version (`dart --version`)
   - Your operating system
   - A minimal reproduction example
   - The full error message

## Version Compatibility

| Polly Dart Version | Dart SDK Version | Status |
|-------------------|------------------|---------|
| **0.1.x** | ≥ 3.5.0 | Current |
| **Future versions** | ≥ 3.5.0 | Planned |

We follow [semantic versioning](https://semver.org/) for predictable updates.
