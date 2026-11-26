# AI Text Anon – Project Status

## Application Foundation

- [x] Native macOS SwiftUI application
- [x] Product name: `AI Text Anon`
- [x] Developer and publisher: `Laura Renning`
- [x] Bundle identifier: `com.contentanonymizer.ContentAnonymizer`
- [x] macOS 13.0 deployment target
- [x] Reusable SwiftUI design foundation
- [x] Light/Dark Mode adaptive UI
- [x] Proper macOS App Icon
- [x] German UI localization with English as the base/fallback language

## Anonymization Detection

- [x] Email detection
- [x] IBAN detection
- [x] IPv4 detection
- [x] IPv6 detection
- [x] HTTP/HTTPS URL detection
- [x] Plain-domain detection
- [x] Contextual password/secret detection
- [x] Contextual token/API-key detection
- [x] Phone-number detection
- [x] MAC-address detection
- [x] UUID detection
- [x] Local NaturalLanguage person detection
- [x] Local NaturalLanguage organization detection
- [x] Local NaturalLanguage location detection
- [x] Conservative German postal-address detection
- [x] Narrow `Projekt` / `Project` fallback detection as `[CUSTOM_n]`
- [x] Conservative person-alias propagation for unambiguous first names
- [x] Embedded legal-form organization fallback detection
- [x] Manual text selection and category assignment
- [x] Custom manual detections with `[CUSTOM_n]` placeholders
- [x] Optional local Foundation Models detection
- [x] Explicit Analyze Text workflow for structured, NaturalLanguage, and optional local AI detection
- [ ] Full international postal-address detection
- [ ] Phone-number validation against a global numbering database

## Anonymization Controls

- [x] Deterministic, category-specific placeholders
- [x] Consistent mappings for repeated normalized values
- [x] Category-level selection
- [x] Per-detection selection
- [x] Select All / Select None categories
- [x] Select All Items / Select None Items
- [x] Scrollable detected-item preview
- [x] Collapsible Anonymization section
- [x] Collapsible Detected Items section
- [x] Copy anonymized text to the macOS clipboard
- [x] Manual detection selection and removal
- [x] Local AI candidate preview with explicit opt-in
- [x] Analysis status and indeterminate progress feedback

## Restore Workflow

- [x] In-memory placeholder-to-original mapping session
- [x] Restore AI-edited text with exact placeholders
- [x] Restore repeated and reordered placeholders
- [x] Report unknown or modified placeholders without guessing
- [x] Report known placeholders missing from the supplied text
- [x] Copy restored text to the macOS clipboard
- [x] Restore support for manual and Custom detections
- [x] Explicit Clear Restore Data / new-session action
- [x] New anonymization replaces the previous active restore session
- [x] Unified bidirectional editor workspace
- [x] Anonymize Internal Text → Anonymized / External Text
- [x] Restore Anonymized / External Text → Internal Text
- [ ] Multiple saved restore sessions
- [ ] Fuzzy recovery of modified placeholders

## UI / UX

- [x] Original and anonymized text editors
- [x] Translator-style responsive bidirectional Internal Text ↔ Anonymized / External Text workspace
- [x] Clear actions for Internal Text and Anonymized / External Text
- [x] Compact copy-icon controls in both editor headers
- [x] Secondary Restore-session reset action in the overflow menu
- [x] Native right-click manual sensitive marking with category submenu
- [x] Gear button with Anonymization Settings modal
- [x] Local static Help view with localized workflow and privacy guidance
- [x] Detailed Local AI availability diagnostics and System Settings guidance
- [x] Stable native text selection in the Original Text editor
- [x] Visual highlighting of effective detected ranges in Original Text
- [x] Restore action uses the shared right-to-left editor workflow
- [x] Native macOS controls and accessibility labels
- [x] Placeholder-preservation guidance for AI rewriting
- [x] Detection-source labels in Detected Items for real-world testing
- [ ] Optional final UI polish after daily-use feedback

## Privacy

- [x] All processing remains local and in-memory
- [x] No networking or cloud services
- [x] No analytics or telemetry
- [x] No persistence of pasted text or restore mappings
- [x] No logging of source, detected, anonymized, or restored values
- [x] No external dependencies

## Testing

- [x] Unit tests for structured detection and anonymization
- [x] Unit tests for NaturalLanguage integration
- [x] Unit tests for category and per-detection filtering
- [x] Unit tests for address detection and false positives
- [x] Unit tests for restore, missing, unknown, and modified placeholders
- [x] Detection-source tests for structured, NaturalLanguage, Local AI, manual, address, and fallback paths
- [x] 112 tests currently pass
- [ ] Record the effective detection source when reporting entity false positives or false negatives
- [ ] Real-world testing over several weeks
- [ ] Collect false-positive and false-negative examples
- [ ] Broader language regression coverage for NaturalLanguage
- [ ] Refine German address coverage from real-world examples
- [ ] Test optional Local AI detection on supported Apple Intelligence hardware

## Packaging and Distribution

- [x] MIT License
- [x] Debug build
- [x] Local Release build
- [x] Local app bundle launch
- [x] App Icon asset catalog and compiled `AppIcon.icns`
- [ ] Developer ID signing
- [ ] Apple notarization
- [ ] ZIP or DMG distribution package
- [ ] Versioning and release workflow

## Known Limitations

- [ ] NaturalLanguage entity detection may vary with context, language, and macOS version.
- [ ] Person-alias propagation is intentionally disabled when the first name is ambiguous.
- [ ] Local AI detection is opt-in, available only on macOS 26+ with a ready on-device model, and remains probabilistic.
- [ ] Postal-address detection is currently focused on common German formats.
- [ ] International address parsing is not implemented.
- [ ] Phone detection is format-based rather than backed by a global numbering database.
- [ ] Restore requires exact, unchanged placeholders.
- [ ] Restore mappings are intentionally lost when the active session is reset or the application closes.
- [ ] Multiple saved restore sessions are not available.
- [ ] The local build is unsigned/ad-hoc and is not prepared for broad external distribution.

## Future Ideas

- [ ] Optional persistent preferences for UI and category defaults
- [ ] Secure saved sessions only if a later workflow requires them
- [ ] File import/export
- [ ] PDF and document processing
- [ ] Clipboard automation or monitoring
- [ ] AI/API integration with external services (not planned for the local-only design)

The future ideas above are exploratory and are not committed scope.
