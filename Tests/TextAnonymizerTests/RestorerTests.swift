import XCTest
@testable import TextAnonymizer

final class RestorerTests: XCTestCase {
    private let anonymizer = Anonymizer()
    private let restorer = Restorer()

    func testBasicRestoration() {
        let session = AnonymizationSession(mappings: [
            "[PERSON_1]": "Max Mustermann",
            "[EMAIL_1]": "max@example.com"
        ])

        let result = restorer.restore(
            "Guten Tag [PERSON_1], schreiben Sie an [EMAIL_1].",
            using: session
        )

        XCTAssertEqual(
            result.restoredText,
            "Guten Tag Max Mustermann, schreiben Sie an max@example.com."
        )
        XCTAssertEqual(
            result.restoredPlaceholders,
            ["[PERSON_1]", "[EMAIL_1]"]
        )
        XCTAssertTrue(result.unresolvedPlaceholders.isEmpty)
        XCTAssertTrue(result.missingPlaceholders.isEmpty)
    }

    func testRepeatedPlaceholdersAreRestoredEverywhere() {
        let session = AnonymizationSession(mappings: [
            "[PERSON_1]": "Max Mustermann"
        ])

        let result = restorer.restore(
            "[PERSON_1] hat [PERSON_1] als Ansprechpartner eingetragen.",
            using: session
        )

        XCTAssertEqual(
            result.restoredText,
            "Max Mustermann hat Max Mustermann als Ansprechpartner eingetragen."
        )
        XCTAssertEqual(result.restoredPlaceholders, ["[PERSON_1]"])
    }

    func testReorderedContentIsRestored() {
        let session = AnonymizationSession(mappings: [
            "[PERSON_1]": "Max Mustermann",
            "[EMAIL_1]": "max@example.com"
        ])

        let result = restorer.restore(
            "Kontakt: [EMAIL_1]. Ansprechpartner: [PERSON_1].",
            using: session
        )

        XCTAssertEqual(
            result.restoredText,
            "Kontakt: max@example.com. Ansprechpartner: Max Mustermann."
        )
    }

    func testMissingKnownPlaceholderDoesNotFailRestoration() {
        let session = AnonymizationSession(mappings: [
            "[PERSON_1]": "Max Mustermann",
            "[EMAIL_1]": "max@example.com",
            "[PHONE_1]": "+49 251 123456"
        ])

        let result = restorer.restore(
            "Guten Tag [PERSON_1], schreiben Sie an [EMAIL_1].",
            using: session
        )

        XCTAssertEqual(
            result.restoredText,
            "Guten Tag Max Mustermann, schreiben Sie an max@example.com."
        )
        XCTAssertEqual(result.missingPlaceholders, ["[PHONE_1]"])
        XCTAssertTrue(result.unresolvedPlaceholders.isEmpty)
    }

    func testUnknownPlaceholderRemainsUnchangedAndIsReported() {
        let session = AnonymizationSession(mappings: [
            "[PERSON_1]": "Max Mustermann"
        ])

        let result = restorer.restore(
            "[PERSON_1] und [PERSON_99]",
            using: session
        )

        XCTAssertEqual(result.restoredText, "Max Mustermann und [PERSON_99]")
        XCTAssertEqual(result.unresolvedPlaceholders, ["[PERSON_99]"])
    }

    func testModifiedPlaceholderRemainsUnchangedAndIsReported() {
        let session = AnonymizationSession(mappings: [
            "[PERSON_1]": "Max Mustermann"
        ])

        let result = restorer.restore(
            "[PERSON 1] [Person_1] [PERSON_1]",
            using: session
        )

        XCTAssertEqual(result.restoredText, "[PERSON 1] [Person_1] Max Mustermann")
        XCTAssertEqual(
            Set(result.unresolvedPlaceholders),
            Set(["[PERSON 1]", "[Person_1]"])
        )
    }

    func testIndividuallyDisabledDetectionDoesNotCreateRestoreMapping() {
        let input = "Keep anna@example.com and replace peter@example.com."
        let initialResult = anonymizer.anonymizeWithResult(input)
        let emailIDs = initialResult.detectedItems
            .filter { $0.category == .email }
            .map(\.id)
        let selectedID = try! XCTUnwrap(emailIDs.last)

        let result = anonymizer.anonymizeWithResult(
            input,
            selectedDetectionIDs: [selectedID]
        )
        let session = AnonymizationSession(result: result)

        XCTAssertEqual(result.anonymizedText, "Keep anna@example.com and replace [EMAIL_1].")
        XCTAssertEqual(session.mappings, ["[EMAIL_1]": "peter@example.com"])
    }

    func testGloballyDisabledCategoryDoesNotCreateRestoreMapping() {
        let result = anonymizer.anonymizeWithResult(
            "Contact anna@example.com.",
            enabledCategories: []
        )

        let session = AnonymizationSession(result: result)

        XCTAssertEqual(result.anonymizedText, "Contact anna@example.com.")
        XCTAssertTrue(session.isEmpty)
    }

    func testRepeatedNormalizedReplacementsRestoreSharedPlaceholder() {
        let input = "DE89370400440532013000 / DE89 3704 0044 0532 0130 00"
        let result = anonymizer.anonymizeWithResult(input)
        let session = AnonymizationSession(result: result)

        let restored = restorer.restore(
            "[IBAN_1] und [IBAN_1]",
            using: session
        )

        XCTAssertEqual(restored.restoredText, "DE89370400440532013000 und DE89370400440532013000")
        XCTAssertEqual(session.mappings.count, 1)
    }

    func testAIEditedTechnicalTextRestoresMultipleCategories() {
        let input = "Contact anna@example.com at 192.168.1.25; password=secret"
        let anonymized = anonymizer.anonymizeWithResult(input)
        let session = AnonymizationSession(result: anonymized)

        XCTAssertEqual(
            anonymized.anonymizedText,
            "Contact [EMAIL_1] at [IP_1]; password=[SECRET_1]"
        )

        let restored = restorer.restore(
            "Please contact [EMAIL_1]. The server is [IP_1]. Use password [SECRET_1].",
            using: session
        )

        XCTAssertEqual(
            restored.restoredText,
            "Please contact anna@example.com. The server is 192.168.1.25. Use password secret."
        )
        XCTAssertTrue(restored.unresolvedPlaceholders.isEmpty)
        XCTAssertTrue(restored.missingPlaceholders.isEmpty)
    }

    func testNewAnonymizationReplacesPreviousActiveSession() {
        let first = AnonymizationSession(
            result: anonymizer.anonymizeWithResult("anna@example.com")
        )
        let second = AnonymizationSession(
            result: anonymizer.anonymizeWithResult("peter@example.com")
        )

        let restored = restorer.restore("[EMAIL_1]", using: second)

        XCTAssertEqual(first.mappings, ["[EMAIL_1]": "anna@example.com"])
        XCTAssertEqual(second.mappings, ["[EMAIL_1]": "peter@example.com"])
        XCTAssertEqual(restored.restoredText, "peter@example.com")
    }

    func testClearedSessionLeavesPlaceholderUnchanged() {
        let activeSession = AnonymizationSession(
            result: anonymizer.anonymizeWithResult("anna@example.com")
        )
        let clearedSession = AnonymizationSession(mappings: [:])

        XCTAssertEqual(
            restorer.restore("[EMAIL_1]", using: activeSession).restoredText,
            "anna@example.com"
        )

        let result = restorer.restore("[EMAIL_1]", using: clearedSession)
        XCTAssertEqual(result.restoredText, "[EMAIL_1]")
        XCTAssertEqual(result.unresolvedPlaceholders, ["[EMAIL_1]"])
    }
}
