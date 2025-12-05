# Contributing to Halo iOS

Thank you for your interest in contributing to Halo iOS! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the project goals

## Development Setup

1. **Prerequisites:**
   - macOS 14.0+
   - Xcode 15.0+
   - Swift 5.9+
   - SwiftLint (optional): `brew install swiftlint`
   - SwiftFormat (optional): `brew install swiftformat`

2. **Clone and setup:**
   ```bash
   git clone https://github.com/yourusername/Halo-iOS.git
   cd Halo-iOS
   open Halo-iOS.xcodeproj
   ```

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and use automated tools:

**SwiftFormat:**
```bash
# Format all Swift files
swiftformat .

# Check formatting without changes
swiftformat --lint .
```

**SwiftLint:**
```bash
# Lint all Swift files
swiftlint

# Auto-correct issues where possible
swiftlint --fix
```

### Code Quality Rules

- **Line length:** 120 characters (warning), 150 (error)
- **Function length:** 50 lines (warning), 100 (error)
- **File length:** 500 lines (warning), 1000 (error)
- **Cyclomatic complexity:** 10 (warning), 20 (error)

### Best Practices

1. **Naming:**
   - Use descriptive names
   - Classes/Structs: `PascalCase`
   - Functions/Variables: `camelCase`
   - Constants: `camelCase` or `UPPER_CASE` for globals

2. **Documentation:**
   - Add doc comments for public APIs
   - Use `///` for single-line docs
   - Use `/** ... */` for multi-line docs

3. **Error Handling:**
   - Prefer `throws` over force unwraps
   - Use `guard` for early returns
   - Provide meaningful error messages

4. **Testing:**
   - Write unit tests for business logic
   - Aim for >70% code coverage
   - Use descriptive test names

## Pull Request Process

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes:**
   - Follow coding standards
   - Add tests for new features
   - Update documentation

3. **Run checks:**
   ```bash
   # Format code
   swiftformat .
   
   # Lint code
   swiftlint
   
   # Run tests
   xcodebuild test -project Halo-iOS.xcodeproj \
                    -scheme Halo-iOS \
                    -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add feature description"
   ```

   Commit message format:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `style:` Formatting changes
   - `refactor:` Code restructuring
   - `test:` Adding tests
   - `chore:` Maintenance tasks

5. **Push and create PR:**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a pull request on GitHub.

6. **PR Review:**
   - Address review comments
   - Ensure CI passes
   - Squash commits if needed

## Project Structure

```
Halo-iOS/
├── Halo-iOS/                  # Main app code
│   ├── *AudioEngine.swift     # Audio processing
│   ├── *DSP.swift             # Signal processing
│   ├── *Classifier.swift      # ML/Classification
│   ├── *DataStore.swift       # Persistence
│   ├── ContentView.swift      # UI
│   └── Info.plist             # Configuration
├── Halo-iOSTests/             # Unit tests (future)
├── Halo-iOS.xcodeproj/        # Xcode project
├── .swiftformat               # Format config
├── .swiftlint.yml             # Lint config
├── .gitignore                 # Git ignores
└── README.md                  # Documentation
```

## Testing Guidelines

### Unit Tests

Add tests in `Halo-iOSTests/`:

```swift
import XCTest
@testable import Halo_iOS

final class BreathingDSPTests: XCTestCase {
    var dsp: BreathingDSP!
    
    override func setUp() {
        super.setUp()
        dsp = BreathingDSP(sampleRate: 16000.0)
    }
    
    func testBandpassFilter() {
        let input = [Float](repeating: 1.0, count: 1024)
        let output = dsp.applyBandpassFilter(to: input)
        XCTAssertEqual(output.count, input.count)
    }
}
```

### Test Coverage

Run with coverage:
```bash
xcodebuild test -project Halo-iOS.xcodeproj \
                -scheme Halo-iOS \
                -destination 'platform=iOS Simulator,name=iPhone 16' \
                -enableCodeCoverage YES
```

## Reporting Issues

When reporting bugs, please include:
- iOS version
- Device model
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/logs if applicable

## Feature Requests

For feature requests:
- Describe the problem you're solving
- Explain your proposed solution
- Consider edge cases
- Check if it aligns with project goals

## Questions?

- Open a GitHub issue
- Check existing documentation
- Review closed issues/PRs

Thank you for contributing! 🙏
