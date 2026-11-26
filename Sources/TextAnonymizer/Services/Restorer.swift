import Foundation

struct RestorationResult: Equatable {
    let restoredText: String
    let restoredPlaceholders: [String]
    let unresolvedPlaceholders: [String]
    let missingPlaceholders: [String]

    var hasWarnings: Bool {
        !unresolvedPlaceholders.isEmpty || !missingPlaceholders.isEmpty
    }
}

struct Restorer {
    func restore(
        _ text: String,
        using session: AnonymizationSession
    ) -> RestorationResult {
        let exactPattern = #"\[[A-Z]+_[0-9]+\]"#
        let placeholderLikePattern = #"\[[A-Za-z]+(?:_| )[0-9]+\]"#

        guard
            let exactRegex = try? NSRegularExpression(pattern: exactPattern),
            let placeholderLikeRegex = try? NSRegularExpression(pattern: placeholderLikePattern)
        else {
            return RestorationResult(
                restoredText: text,
                restoredPlaceholders: [],
                unresolvedPlaceholders: [],
                missingPlaceholders: session.mappings.keys.sorted()
            )
        }

        let fullRange = NSRange(location: 0, length: text.utf16.count)
        var edits: [(range: Range<String.Index>, value: String)] = []
        var presentPlaceholders = Set<String>()
        var restoredPlaceholders: [String] = []
        var unresolvedPlaceholders: [String] = []

        for match in exactRegex.matches(in: text, range: fullRange) {
            guard let range = Range(match.range, in: text) else {
                continue
            }

            let placeholder = String(text[range])
            presentPlaceholders.insert(placeholder)

            if let originalValue = session.mappings[placeholder] {
                edits.append((range: range, value: originalValue))
                appendIfMissing(placeholder, to: &restoredPlaceholders)
            } else {
                appendIfMissing(placeholder, to: &unresolvedPlaceholders)
            }
        }

        for match in placeholderLikeRegex.matches(in: text, range: fullRange) {
            guard let range = Range(match.range, in: text) else {
                continue
            }

            let placeholder = String(text[range])
            let isExactPlaceholder = exactRegex.firstMatch(
                in: placeholder,
                range: NSRange(location: 0, length: placeholder.utf16.count)
            ) != nil

            if !isExactPlaceholder {
                appendIfMissing(placeholder, to: &unresolvedPlaceholders)
            }
        }

        var restoredText = text
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            restoredText.replaceSubrange(edit.range, with: edit.value)
        }

        let missingPlaceholders = session.mappings.keys
            .filter { !presentPlaceholders.contains($0) }
            .sorted()

        return RestorationResult(
            restoredText: restoredText,
            restoredPlaceholders: restoredPlaceholders,
            unresolvedPlaceholders: unresolvedPlaceholders,
            missingPlaceholders: missingPlaceholders
        )
    }

    private func appendIfMissing(_ value: String, to values: inout [String]) {
        guard !values.contains(value) else {
            return
        }
        values.append(value)
    }
}
