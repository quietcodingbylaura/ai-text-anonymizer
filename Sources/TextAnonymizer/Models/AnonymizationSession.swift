struct AnonymizationSession: Equatable {
    let mappings: [String: String]

    init(result: AnonymizationResult) {
        self.mappings = Dictionary(
            uniqueKeysWithValues: result.replacements.map {
                ($0.replacementValue, $0.originalValue)
            }
        )
    }

    init(mappings: [String: String]) {
        self.mappings = mappings
    }

    var isEmpty: Bool {
        mappings.isEmpty
    }
}
