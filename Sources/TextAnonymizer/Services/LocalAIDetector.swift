import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum LocalAIAvailability: Equatable {
    case available
    case appleIntelligenceNotEnabled
    case deviceNotEligible
    case modelNotReady
    case unsupportedOS
    case unknown

    var isAvailable: Bool {
        self == .available
    }

    var displayName: String {
        switch self {
        case .available:
            "Available"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence not enabled"
        case .deviceNotEligible:
            "Device not eligible"
        case .modelNotReady:
            "Model not ready"
        case .unsupportedOS:
            "Requires macOS 26 or later"
        case .unknown:
            "Unavailable"
        }
    }

    var localizedDisplayName: String {
        String(localized: String.LocalizationValue(displayName))
    }

    var detail: String {
        switch self {
        case .available:
            "Apple's on-device language model is ready."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is not enabled on this Mac."
        case .deviceNotEligible:
            "This Mac does not support Apple Intelligence."
        case .modelNotReady:
            "The local Apple Intelligence model is not ready yet. macOS manages its download and preparation."
        case .unsupportedOS:
            "Local AI Detection requires macOS 26 or later."
        case .unknown:
            "The local Apple Intelligence model is currently unavailable."
        }
    }

    var localizedDetail: String {
        String(localized: String.LocalizationValue(detail))
    }

    var settingsGuidance: String? {
        switch self {
        case .appleIntelligenceNotEnabled:
            "Enable Apple Intelligence in System Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            "macOS manages the model download and preparation; no app installation is required."
        default:
            nil
        }
    }

    var localizedSettingsGuidance: String? {
        settingsGuidance.map { String(localized: String.LocalizationValue($0)) }
    }

    var canOpenSystemSettings: Bool {
        self == .appleIntelligenceNotEnabled
    }
}

struct LocalAICandidate {
    let value: String
    let category: ReplacementCategory
}

struct LocalAIDetectionResult {
    let availability: LocalAIAvailability
    let matches: [DetectedMatch]
}

struct LocalAICandidateMapper {
    static func matches(
        from candidates: [LocalAICandidate],
        in text: String
    ) -> [DetectedMatch] {
        var matches: [DetectedMatch] = []

        for candidate in candidates
            where [.person, .organization, .location].contains(candidate.category)
                && !candidate.value.isEmpty {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(
                      of: candidate.value,
                      range: searchStart..<text.endIndex
                  ) {
                let match = DetectedMatch(
                    originalValue: candidate.value,
                    category: candidate.category,
                    sourceRange: range,
                    normalizedValue: candidate.value,
                    source: .localAI
                )

                if !matches.contains(where: {
                    $0.category == match.category
                        && $0.sourceRange == match.sourceRange
                }) {
                    matches.append(match)
                }

                guard range.upperBound < text.endIndex else {
                    break
                }
                searchStart = range.upperBound
            }
        }

        return matches
    }
}

struct LocalAIDetector {
    var availability: LocalAIAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return systemModelAvailability()
        }
        #endif
        return .unsupportedOS
    }

    func detect(in text: String) async -> LocalAIDetectionResult {
        guard !text.isEmpty else {
            return LocalAIDetectionResult(
                availability: availability,
                matches: []
            )
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return await detectWithSystemModel(in: text)
        }
        #endif

        return LocalAIDetectionResult(
            availability: .unsupportedOS,
            matches: []
        )
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func systemModelAvailability() -> LocalAIAvailability {
        availability(for: SystemLanguageModel(useCase: .contentTagging).availability)
    }

    @available(macOS 26.0, *)
    private func detectWithSystemModel(in text: String) async -> LocalAIDetectionResult {
        let model = SystemLanguageModel(useCase: .contentTagging)
        let currentAvailability = availability(for: model.availability)
        guard currentAvailability == .available else {
            return LocalAIDetectionResult(
                availability: currentAvailability,
                matches: []
            )
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            Identify potentially sensitive natural-language entities in the supplied text.
            Return only exact contiguous substrings for PERSON, ORGANIZATION, or LOCATION.
            Do not return titles, greetings, closing phrases, structured identifiers, URLs,
            email addresses, or text that is not present verbatim in the supplied text.
            """
        )
        let prompt = """
        Extract exact sensitive natural-language entities from this text.
        Use PERSON for a person name, ORGANIZATION for an organization, and LOCATION for a place.
        If an entity is ambiguous, omit it. The value must be copied exactly from the source text.

        Source text:
        \(text)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: LocalAIGeneratedEntities.self
            )
            let candidates: [LocalAICandidate] = response.content.entities.compactMap {
                (entity: LocalAIGeneratedEntity) -> LocalAICandidate? in
                guard let category = category(for: entity.category) else {
                    return nil
                }
                return LocalAICandidate(value: entity.value, category: category)
            }

            return LocalAIDetectionResult(
                availability: .available,
                matches: LocalAICandidateMapper.matches(from: candidates, in: text)
            )
        } catch {
            return LocalAIDetectionResult(
                availability: .unknown,
                matches: []
            )
        }
    }

    @available(macOS 26.0, *)
    private func availability(
        for value: SystemLanguageModel.Availability
    ) -> LocalAIAvailability {
        switch value {
        case .available:
            .available
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                .appleIntelligenceNotEnabled
            case .deviceNotEligible:
                .deviceNotEligible
            case .modelNotReady:
                .modelNotReady
            @unknown default:
                .unknown
            }
        }
    }

    @available(macOS 26.0, *)
    private func category(for value: String) -> ReplacementCategory? {
        switch value.uppercased() {
        case "PERSON":
            .person
        case "ORGANIZATION":
            .organization
        case "LOCATION":
            .location
        default:
            nil
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
struct LocalAIGeneratedEntities: Sendable {
    let entities: [LocalAIGeneratedEntity]
}

@available(macOS 26.0, *)
@Generable
struct LocalAIGeneratedEntity: Sendable {
    let value: String
    let category: String
}
#endif
