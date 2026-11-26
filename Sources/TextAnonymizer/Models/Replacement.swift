import Foundation

enum AnalysisState: Equatable {
    case idle
    case analyzing
    case complete
    case stale
    case unavailable(String)
    case failed(String)
}

enum ReplacementCategory: String, CaseIterable, Hashable {
    case email
    case phone
    case ip
    case url
    case domain
    case iban
    case secret
    case token
    case mac
    case uuid
    case address
    case person
    case organization
    case location
    case custom

    static let allCategories = Set(allCases)

    static let manualCategories: [ReplacementCategory] = [
        .person,
        .organization,
        .location,
        .address,
        .email,
        .phone,
        .domain,
        .url,
        .secret,
        .token,
        .iban,
        .custom
    ]

    var displayName: String {
        switch self {
        case .email:
            "Email"
        case .phone:
            "Phone"
        case .ip:
            "IP Address"
        case .url:
            "URL"
        case .domain:
            "Domain"
        case .iban:
            "IBAN"
        case .secret:
            "Password / Secret"
        case .token:
            "Token / API Key"
        case .mac:
            "MAC Address"
        case .uuid:
            "UUID"
        case .address:
            "Address"
        case .person:
            "Person Name"
        case .organization:
            "Organization"
        case .location:
            "Location"
        case .custom:
            "Custom"
        }
    }

    var localizedDisplayName: String {
        String(localized: String.LocalizationValue(displayName))
    }

    var placeholderPrefix: String {
        rawValue.uppercased()
    }

    // Lower numeric priorities are selected first; NaturalLanguage entities
    // intentionally remain below all structured detections.
    var detectionPriority: Int {
        switch self {
        case .url:
            0
        case .email:
            1
        case .secret, .token:
            2
        case .iban:
            3
        case .uuid:
            5
        case .address:
            4
        case .mac:
            6
        case .ip:
            7
        case .phone:
            8
        case .domain:
            9
        case .person, .organization, .location, .custom:
            10
        }
    }
}

enum DetectionSource: String, Hashable {
    case structured
    case naturalLanguage
    case localAI
    case manual
    case addressRule
    case fallbackRule

    var displayName: String {
        switch self {
        case .structured:
            "Structured"
        case .naturalLanguage:
            "Natural Language"
        case .localAI:
            "Local AI"
        case .manual:
            "Manual"
        case .addressRule:
            "Address Rule"
        case .fallbackRule:
            "Fallback Rule"
        }
    }

    var localizedDisplayName: String {
        String(localized: String.LocalizationValue(displayName))
    }

    var priority: Int {
        switch self {
        case .manual:
            0
        case .structured, .naturalLanguage, .addressRule, .fallbackRule:
            1
        case .localAI:
            2
        }
    }
}

struct Replacement: Equatable {
    let originalValue: String
    let replacementValue: String
    let category: ReplacementCategory
}

struct AnonymizationResult: Equatable {
    let anonymizedText: String
    let replacements: [Replacement]
    let detectedItems: [DetectedItem]

    var detectionHighlights: [DetectionHighlight] {
        detectedItems.map(DetectionHighlight.init)
    }

    func detectionHighlights(for state: AnalysisState) -> [DetectionHighlight] {
        state == .complete ? detectionHighlights : []
    }
}

struct DetectionHighlight: Equatable {
    let range: NSRange
    let isActive: Bool

    init(range: NSRange, isActive: Bool) {
        self.range = range
        self.isActive = isActive
    }

    init(item: DetectedItem) {
        self.init(
            range: NSRange(
                location: item.id.startOffset,
                length: item.id.length
            ),
            isActive: item.isAnonymized
        )
    }
}

struct DetectedMatch {
    let originalValue: String
    let category: ReplacementCategory
    let sourceRange: Range<String.Index>
    let normalizedValue: String
    let source: DetectionSource

    init(
        originalValue: String,
        category: ReplacementCategory,
        sourceRange: Range<String.Index>,
        normalizedValue: String,
        source: DetectionSource = .structured
    ) {
        self.originalValue = originalValue
        self.category = category
        self.sourceRange = sourceRange
        self.normalizedValue = normalizedValue
        self.source = source
    }
}

struct DetectionID: Hashable {
    let category: ReplacementCategory
    let startOffset: Int
    let length: Int

    init(category: ReplacementCategory, startOffset: Int, length: Int) {
        self.category = category
        self.startOffset = startOffset
        self.length = length
    }

    init(match: DetectedMatch, in text: String) {
        let range = NSRange(match.sourceRange, in: text)
        self.init(
            category: match.category,
            startOffset: range.location,
            length: range.length
        )
    }
}

struct ManualDetection: Equatable, Hashable, Identifiable {
    let sourceRange: NSRange
    let originalValue: String
    let category: ReplacementCategory
    private let sourceTextHash: Int

    var id: DetectionID {
        DetectionID(
            category: category,
            startOffset: sourceRange.location,
            length: sourceRange.length
        )
    }

    init?(
        text: String,
        sourceRange: NSRange,
        category: ReplacementCategory
    ) {
        guard sourceRange.length > 0,
              let range = Range(sourceRange, in: text) else {
            return nil
        }

        let value = String(text[range])
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.sourceRange = sourceRange
        self.originalValue = value
        self.category = category
        self.sourceTextHash = text.hashValue
    }

    func match(in text: String) -> DetectedMatch? {
        guard text.hashValue == sourceTextHash,
              let range = Range(sourceRange, in: text),
              String(text[range]) == originalValue else {
            return nil
        }

        return DetectedMatch(
            originalValue: originalValue,
            category: category,
            sourceRange: range,
            normalizedValue: originalValue,
            source: .manual
        )
    }
}

struct DetectedItem: Equatable, Hashable, Identifiable {
    let id: DetectionID
    let originalValue: String
    let category: ReplacementCategory
    let replacementValue: String?
    let source: DetectionSource

    var isAnonymized: Bool {
        replacementValue != nil
    }
}
