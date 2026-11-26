# AI Text Anon

AI Text Anon is a privacy-focused application for detecting and anonymizing sensitive text before it is shared with AI systems.

The repository is named `ai-text-anonymizer`, while the application is called AI Text Anon. The subtitle is: “Anonymize sensitive text before sharing it with AI.”

The current implementation is a native macOS SwiftUI application. Windows support is planned, with platform-independent anonymization logic intended to be shared across both platforms.

Developer and publisher: quietcodingbylaura.

The application is designed for local processing. The current foundation does not write pasted text to disk, log text, contact external services, or include analytics, telemetry, crash reporting, or API integrations.

## Current status

The current macOS user interface supports English as the base language and German (Deutsch) as an additional localization. The app follows the user's normal macOS language preference; English remains the fallback.

The detection layer combines deterministic structured-data detection with local Apple NaturalLanguage named-entity detection for people, organizations, and locations. Structured detection covers practical email, IBAN, IPv4, IPv6, phone number, MAC address, UUID, conservative German postal addresses, HTTP(S) URL, and plain-domain matches, plus conservatively recognized password/secret assignments and API key/token contexts. Full international address parsing and broader secret-format databases are intentionally not included.

NaturalLanguage processing happens locally on the Mac through Apple's native framework. The interface includes an in-memory detection preview with safe-by-default per-category and per-detection controls. Disabled detections remain visible in the preview but are left unchanged in the generated output.

For names or project-specific values that automatic detection misses, select text in Internal Text and use the native right-click menu: Mark as Sensitive, then choose a category. Manual classifications use the same replacement and Restore workflow; Custom is available for arbitrary sensitive values. Optional Local AI Detection is off by default and, when supported, uses only Apple's on-device Foundation Models on macOS 26 or newer. It has no network fallback.

Detection is explicit: paste or edit the source, click Analyze Text, review the current detections, and then click Anonymize. Editing the source marks the previous analysis as stale so old source ranges are not reused. The main workspace uses one bidirectional pair of editors: Internal Text flows right to Anonymized / External Text with Anonymize, and edited anonymized text flows back left with Restore. The editors are side by side on wide windows and stack on narrow windows.

Use the Help button in the header for the local workflow and privacy guidance. Use the gear button to open Anonymization Settings. Category toggles and the optional Local AI Detection diagnostics are managed there. Clear beside Internal Text removes the current source and detections without discarding the in-memory Restore session; Clear on the right removes only the external text.

## Current platform and roadmap

The current release targets macOS 13 and newer. A Windows version is planned; the platform-independent anonymization logic and test coverage are intended to be shared while the user interface and operating-system integrations are adapted for each platform.

## Build and run on macOS

Requires macOS with Swift 6 or Xcode 26 (or a compatible newer version). The app target uses macOS 13.0 as its deployment target.

```sh
xcodebuild -project TextAnonymizer.xcodeproj -scheme TextAnonymizer -configuration Debug build
xcodebuild test -project TextAnonymizer.xcodeproj -scheme TextAnonymizer -destination 'platform=macOS'
```

## Open and run in Xcode

1. Open `TextAnonymizer.xcodeproj`.
2. Select the `TextAnonymizer` scheme.
3. Select `My Mac` as the run destination.
4. Click Run.

The app target produces `AI Text Anon.app` and uses the bundle identifier `com.contentanonymizer.ContentAnonymizer`. The shared scheme also runs the `TextAnonymizerTests` XCTest target.

The current implementation also includes an in-memory restore workflow: after anonymizing, edit the right-side external text while keeping placeholders unchanged, then use Restore to write the restored result back into Internal Text. Restore mappings are discarded when a new anonymization session or explicit restore-data reset is created.

For a living implementation checklist and current limitations, see [`docs/PROJECT-STATUS.md`](docs/PROJECT-STATUS.md).

## macOS app icon and local Release build

The macOS AppIcon asset catalog is at `Sources/TextAnonymizer/Resources/Assets.xcassets`. The original `ContentAnonymizerIcon_1024x1024.png` remains in the repository root as icon version 1. The active icon is version 2, based on `ContentAnonymizerIcon_v2_1024x1024.png`; it keeps the rounded light-lilac icon face while making the outer corners transparent. `build-release.sh` regenerates all ten Xcode icon variants from this V2 master before building.

Build an isolated Release application with:

```sh
xcodebuild -project TextAnonymizer.xcodeproj -scheme TextAnonymizer -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/text-anonymizer-release-derived-data build
```

The resulting application is:

```text
/tmp/text-anonymizer-release/Build/Products/Release/AI Text Anon.app
```

You can launch it directly or copy it to `/Applications` in Finder. To copy it from Terminal after reviewing the path, use:

```sh
cp -R "/tmp/text-anonymizer-release/Build/Products/Release/AI Text Anon.app" /Applications/
```

The local Release configuration uses ad-hoc/disabled signing suitable for development on this Mac. Distribution signing, notarization, installers, and automatic updates are not configured.

## Project structure

```text
TextAnonymizer.xcodeproj/
└── Native macOS app and XCTest target configuration

Sources/TextAnonymizer/
├── App/          SwiftUI application entry point
├── Views/        Main application interface
├── Models/       Replacement model
├── Services/     Anonymizer and future detection services
├── Design/       Reusable theme tokens and SwiftUI components
└── Utilities/    macOS clipboard helper

Tests/TextAnonymizerTests/
└── AnonymizerTests.swift
```

## License

AI Text Anon is released under the MIT License. See [LICENSE](LICENSE).
