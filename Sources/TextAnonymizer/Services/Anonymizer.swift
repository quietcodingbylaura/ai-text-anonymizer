struct Anonymizer {
    func anonymize(_ text: String) -> String {
        anonymizeWithResult(text).anonymizedText
    }

    func anonymize(
        _ text: String,
        enabledCategories: Set<ReplacementCategory>
    ) -> String {
        anonymizeWithResult(text, enabledCategories: enabledCategories).anonymizedText
    }

    func anonymizeWithResult(
        _ text: String,
        enabledCategories: Set<ReplacementCategory> = ReplacementCategory.allCategories,
        selectedDetectionIDs: Set<DetectionID>? = nil,
        manualDetections: [ManualDetection] = [],
        localAIDetections: [DetectedMatch] = [],
        detectedMatches: [DetectedMatch]? = nil
    ) -> AnonymizationResult {
        // Resolve structural overlaps before filtering so disabling a URL cannot
        // cause a contained domain to partially rewrite that URL. Manual ranges
        // are considered before automatic ranges because they are explicit user
        // decisions.
        let automaticMatches = detectedMatches ?? detectMatches(in: text)
        let manualMatches = manualDetections.compactMap { $0.match(in: text) }
        let selectedMatches = selectNonOverlappingMatches(
            from: automaticMatches + localAIDetections + manualMatches
        )
        let orderedMatches = selectedMatches.sorted {
            $0.sourceRange.lowerBound < $1.sourceRange.lowerBound
        }

        var counters: [ReplacementCategory: Int] = [:]
        var placeholders: [MappingKey: String] = [:]
        var replacements: [Replacement] = []
        var edits: [(range: Range<String.Index>, value: String)] = []
        var detectedItems: [DetectedItem] = []

        for match in orderedMatches {
            let detectionID = DetectionID(match: match, in: text)
            let key = MappingKey(
                category: match.category,
                normalizedValue: match.normalizedValue
            )
            var placeholder: String?
            let isSelected = selectedDetectionIDs?.contains(detectionID) ?? true

            if enabledCategories.contains(match.category) && isSelected {
                if let existingPlaceholder = placeholders[key] {
                    placeholder = existingPlaceholder
                } else {
                    let nextNumber = (counters[match.category] ?? 0) + 1
                    counters[match.category] = nextNumber
                    let newPlaceholder = "[\(match.category.placeholderPrefix)_\(nextNumber)]"
                    placeholders[key] = newPlaceholder
                    placeholder = newPlaceholder
                    replacements.append(
                        Replacement(
                            originalValue: match.originalValue,
                            replacementValue: newPlaceholder,
                            category: match.category
                        )
                    )
                }

                if let placeholder {
                    edits.append((range: match.sourceRange, value: placeholder))
                }
            }

            detectedItems.append(
                DetectedItem(
                    id: detectionID,
                    originalValue: match.originalValue,
                    category: match.category,
                    replacementValue: placeholder,
                    source: match.source
                )
            )
        }

        var anonymizedText = text
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            anonymizedText.replaceSubrange(edit.range, with: edit.value)
        }

        return AnonymizationResult(
            anonymizedText: anonymizedText,
            replacements: replacements,
            detectedItems: detectedItems
        )
    }

    func detectMatches(in text: String) -> [DetectedMatch] {
        PatternDetector().detect(in: text)
            + EntityDetector().detect(in: text)
    }

    private func selectNonOverlappingMatches(
        from matches: [DetectedMatch]
    ) -> [DetectedMatch] {
        let prioritizedMatches = matches.sorted(by: { first, second in
            if first.source.priority != second.source.priority {
                return first.source.priority < second.source.priority
            }
            if first.category.detectionPriority != second.category.detectionPriority {
                return first.category.detectionPriority < second.category.detectionPriority
            }
            if first.sourceRange.lowerBound != second.sourceRange.lowerBound {
                return first.sourceRange.lowerBound < second.sourceRange.lowerBound
            }
            return first.originalValue.utf16.count > second.originalValue.utf16.count
        })

        var selected: [DetectedMatch] = []
        for match in prioritizedMatches {
            guard !selected.contains(where: { rangesOverlap($0.sourceRange, match.sourceRange) }) else {
                continue
            }
            selected.append(match)
        }
        return selected
    }

    private func rangesOverlap(
        _ first: Range<String.Index>,
        _ second: Range<String.Index>
    ) -> Bool {
        first.lowerBound < second.upperBound && second.lowerBound < first.upperBound
    }

    private struct MappingKey: Hashable {
        let category: ReplacementCategory
        let normalizedValue: String
    }
}
