import XCTest
@testable import TextAnonymizer

final class AnonymizerTests: XCTestCase {
    private let anonymizer = Anonymizer()

    func testEmptyTextIsUnchanged() {
        XCTAssertEqual(anonymizer.anonymize(""), "")
    }

    func testSingleEmail() {
        XCTAssertEqual(
            anonymizer.anonymize("Contact anna@example.com."),
            "Contact [EMAIL_1]."
        )
    }

    func testMultipleRepeatedAndPlusAddressEmails() {
        let input = "anna@example.com, anna@example.com, and john+test@example.co.uk."
        let expected = "[EMAIL_1], [EMAIL_1], and [EMAIL_2]."

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testCompactAndSpacedIBANsSharePlaceholder() {
        let input = "DE89370400440532013000 / DE89 3704 0044 0532 0130 00"
        let expected = "[IBAN_1] / [IBAN_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testValidIPv4AddressesAndRepeatedValue() {
        let input = "Servers: 192.168.1.25 and 10.0.0.1; again 192.168.1.25."
        let expected = "Servers: [IP_1] and [IP_2]; again [IP_1]."

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testInvalidIPv4IsNotReplaced() {
        XCTAssertEqual(
            anonymizer.anonymize("Invalid address: 999.999.999.999"),
            "Invalid address: 999.999.999.999"
        )
    }

    func testCommonIPv6Forms() {
        let input = "IPv6: 2001:0db8:85a3:0000:0000:8a2e:0370:7334, ::1, and 2001:db8::1."
        let expected = "IPv6: [IP_1], [IP_2], and [IP_3]."

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testGermanPhoneFormatsAndNormalization() {
        let input = "+49 251 123456 | +49 251 123 456 | +49 (251) 123456 | 0049 251 123456 | 0251 123456 | 0251 / 123456 | 0251-123456 | 0171 1234567 | +49 171 1234567"
        let expected = "[PHONE_1] | [PHONE_1] | [PHONE_1] | [PHONE_2] | [PHONE_3] | [PHONE_3] | [PHONE_3] | [PHONE_4] | [PHONE_5]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testInternationalPhoneFormats() {
        let input = "+1 415 555 1234 and +44 20 7946 0958"
        XCTAssertEqual(anonymizer.anonymize(input), "[PHONE_1] and [PHONE_2]")
    }

    func testPhoneFalsePositivesRemainUnchanged() {
        let input = "123 2026 12345 1.2.3 192.168.1.1 2026-08-14 550e8400-e29b-41d4-a716-446655440000"
        let expected = "123 2026 12345 1.2.3 [IP_1] 2026-08-14 [UUID_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testMobilePhoneWithSevenDigitSubscriberIsDetected() {
        let input = "+49 171 7654321"
        XCTAssertEqual(anonymizer.anonymize(input), "[PHONE_1]")
    }

    func testMACAddressesNormalizeCaseAndSeparators() {
        let input = "00:1A:2B:3C:4D:5E 00-1a-2b-3c-4d-5e 00:1a:2b:3c:4d:5e"
        let expected = "[MAC_1] [MAC_1] [MAC_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testMalformedMACAddressesRemainUnchanged() {
        let input = "00:1A:2B:3C:4D 00:1A-2B:3C:4D:5E 00:1A:2B:3C:4D:5E:6F"

        XCTAssertEqual(anonymizer.anonymize(input), input)
    }

    func testUUIDsNormalizeCase() {
        let input = "550e8400-e29b-41d4-a716-446655440000 550E8400-E29B-41D4-A716-446655440000 6ba7b810-9dad-11d1-80b4-00c04fd430c8"
        let expected = "[UUID_1] [UUID_1] [UUID_2]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testMalformedUUIDsRemainUnchanged() {
        let input = "550e8400-e29b-41d4-a716-44665544000 550e8400-e29b-41d4-a716-4466554400000 550e8400-e29b-41d4-a716-44665544000g"

        XCTAssertEqual(anonymizer.anonymize(input), input)
    }

    func testHTTPURL() {
        XCTAssertEqual(
            anonymizer.anonymize("Open http://example.org/test."),
            "Open [URL_1]."
        )
    }

    func testHTTPSURLWithPathAndQuery() {
        let input = "https://sub.example.de/path?foo=bar&active=true"
        XCTAssertEqual(anonymizer.anonymize(input), "[URL_1]")
    }

    func testDomains() {
        let input = "example.com api.example.de sub.example.co.uk"
        let expected = "[DOMAIN_1] [DOMAIN_2] [DOMAIN_3]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testRepeatedURLsAndDomainsSharePlaceholders() {
        let input = "https://example.com/path https://example.com/path example.com example.com"
        let expected = "[URL_1] [URL_1] [DOMAIN_1] [DOMAIN_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testDottedVersionsAndIPv4AreNotDomains() {
        let input = "192.168.1.1 1.2.3 v1.2.3"
        XCTAssertEqual(anonymizer.anonymize(input), "[IP_1] 1.2.3 v1.2.3")
    }

    func testEmailAndURLDomainsAreNotReplacedSeparately() {
        let input = "anna@example.com https://api.example.com/path"
        let expected = "[EMAIL_1] [URL_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testUnquotedSecretAssignmentsPreserveSyntax() {
        let input = "password=SuperSecret123! password: abc123 DB_PASSWORD=database-secret"
        let expected = "password=[SECRET_1] password: [SECRET_2] DB_PASSWORD=[SECRET_3]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testQuotedSecretAssignmentsPreserveQuotes() {
        let input = "password=\"secret value\" password='another secret'"
        let expected = "password=\"[SECRET_1]\" password='[SECRET_2]'"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testNamedSecretAssignmentsAndUsingPassword() {
        let input = "MYSQL_PASSWORD=mysql-secret SMTP_PASSWORD=smtp-secret; using password 'access-secret'"
        let expected = "MYSQL_PASSWORD=[SECRET_1] SMTP_PASSWORD=[SECRET_2]; using password '[SECRET_3]'"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testClientSecretAssignment() {
        XCTAssertEqual(
            anonymizer.anonymize("client_secret=client-secret-value"),
            "client_secret=[SECRET_1]"
        )
    }

    func testTokenAssignmentsPreserveSyntax() {
        let input = "api_key=abcdef123 API_KEY=second-key access_token=access-123 token=plain-token"
        let expected = "api_key=[TOKEN_1] API_KEY=[TOKEN_2] access_token=[TOKEN_3] token=[TOKEN_4]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testAuthorizationBearerTokenPreservesHeader() {
        XCTAssertEqual(
            anonymizer.anonymize("Authorization: Bearer abc.def.ghi"),
            "Authorization: Bearer [TOKEN_1]"
        )
    }

    func testCredentialValuesWithSameTextShareCategoryPlaceholder() {
        let input = "password=shared token=shared password='shared' token=shared"
        let expected = "password=[SECRET_1] token=[TOKEN_1] password='[SECRET_1]' token=[TOKEN_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testOrdinaryCredentialWordsAndRandomStringsAreNotReplaced() {
        let input = "The password requirements are at least 12 characters. The token system is enabled. This is a secret feature. Random abcDEF123!"

        XCTAssertEqual(anonymizer.anonymize(input), input)
    }

    func testURLWinsOverEmailAndDomainMatches() {
        let input = "https://user@example.com/path and https://api.example.com/path"
        XCTAssertEqual(anonymizer.anonymize(input), "[URL_1] and [URL_2]")
    }

    func testTokenWinsOverDomainInsideTokenValue() {
        XCTAssertEqual(
            anonymizer.anonymize("token=api.example.com"),
            "token=[TOKEN_1]"
        )
    }

    func testNumberingIsIndependentPerCategory() {
        let input = "anna@example.com peter@example.com example.com customer.de password=foo token=bar"
        let expected = "[EMAIL_1] [EMAIL_2] [DOMAIN_1] [DOMAIN_2] password=[SECRET_1] token=[TOKEN_1]"

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testPhoneMACAndUUIDNumberingIsIndependent() {
        let input = "+49 251 123456 +49 171 7654321 00:1A:2B:3C:4D:5E 550e8400-e29b-41d4-a716-446655440000"
        let expected = "[PHONE_1] [PHONE_2] [MAC_1] [UUID_1]"

        let detectedPhones = PatternDetector()
            .detect(in: input)
            .filter { $0.category == .phone }
            .map(\.originalValue)
        XCTAssertEqual(detectedPhones, ["+49 251 123456", "+49 171 7654321"])
        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testNumberingRestartsForEachOperation() {
        XCTAssertEqual(anonymizer.anonymize("first@example.com"), "[EMAIL_1]")
        XCTAssertEqual(anonymizer.anonymize("second@example.com"), "[EMAIL_1]")
    }

    func testAnonymizationResultContainsUniqueReplacementMappings() {
        let result = anonymizer.anonymizeWithResult("anna@example.com anna@example.com")

        XCTAssertEqual(result.anonymizedText, "[EMAIL_1] [EMAIL_1]")
        XCTAssertEqual(
            result.replacements,
            [
                Replacement(
                    originalValue: "anna@example.com",
                    replacementValue: "[EMAIL_1]",
                    category: .email
                )
            ]
        )
    }

    func testCombinedTechnicalInputPreservesContext() {
        let input = """
        Connecting to api.customer-example.de

        Server: 192.168.1.25
        MAC: 00:1A:2B:3C:4D:5E
        Device ID: 550e8400-e29b-41d4-a716-446655440000
        Support phone: +49 251 123456
        User: admin
        DB_PASSWORD=SuperSecret123!

        API endpoint:
        https://api.customer-example.de/v1/users

        Authorization: Bearer abc.def.ghi

        Contact:
        admin@example.com

        Bank:
        DE89 3704 0044 0532 0130 00
        """
        let expected = """
        Connecting to [DOMAIN_1]

        Server: [IP_1]
        MAC: [MAC_1]
        Device ID: [UUID_1]
        Support phone: [PHONE_1]
        User: admin
        DB_PASSWORD=[SECRET_1]

        API endpoint:
        [URL_1]

        Authorization: Bearer [TOKEN_1]

        Contact:
        [EMAIL_1]

        Bank:
        [IBAN_1]
        """

        XCTAssertEqual(anonymizer.anonymize(input), expected)
    }

    func testDisabledURLLeavesURLUnchangedWhileEmailIsAnonymized() {
        let input = "Email: anna@example.com Website: https://example.com"
        let enabledCategories: Set<ReplacementCategory> = [.email]

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: enabledCategories),
            "Email: [EMAIL_1] Website: https://example.com"
        )
    }

    func testDisabledDomainLeavesPlainDomainUnchanged() {
        let input = "Domain: example.com Email: anna@example.com"
        let enabledCategories: Set<ReplacementCategory> = [.email]

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: enabledCategories),
            "Domain: example.com Email: [EMAIL_1]"
        )
    }

    func testDisabledSecretLeavesPasswordValueUnchanged() {
        let input = "DB_PASSWORD=secret Email: anna@example.com"
        let enabledCategories: Set<ReplacementCategory> = [.email]

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: enabledCategories),
            "DB_PASSWORD=secret Email: [EMAIL_1]"
        )
    }

    func testEnabledSecretStillReplacesPasswordValue() {
        XCTAssertEqual(
            anonymizer.anonymize(
                "DB_PASSWORD=secret",
                enabledCategories: [.secret]
            ),
            "DB_PASSWORD=[SECRET_1]"
        )
    }

    func testSelectiveMultipleCategoriesPreserveDisabledMatches() {
        let input = "Email: anna@example.com URL: https://example.com IP: 192.168.1.25 Secret: DB_PASSWORD=secret Phone: +49 251 123456"
        let enabledCategories: Set<ReplacementCategory> = [.email, .ip, .phone]
        let expected = "Email: [EMAIL_1] URL: https://example.com IP: [IP_1] Secret: DB_PASSWORD=secret Phone: [PHONE_1]"

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: enabledCategories),
            expected
        )
    }

    func testDisabledCategoriesDoNotConsumeEnabledPlaceholderNumbers() {
        let input = "https://one.example.com https://two.example.com anna@example.com"
        let enabledCategories: Set<ReplacementCategory> = [.email]
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: enabledCategories
        )

        XCTAssertEqual(
            result.anonymizedText,
            "https://one.example.com https://two.example.com [EMAIL_1]"
        )
        XCTAssertEqual(result.replacements.count, 1)
        XCTAssertEqual(result.replacements.first?.replacementValue, "[EMAIL_1]")
    }

    func testRepeatedEnabledValuesRemainConsistentWhenOtherCategoriesAreDisabled() {
        let input = "anna@example.com anna@example.com DB_PASSWORD=secret DB_PASSWORD=secret"
        let enabledCategories: Set<ReplacementCategory> = [.email]

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: enabledCategories),
            "[EMAIL_1] [EMAIL_1] DB_PASSWORD=secret DB_PASSWORD=secret"
        )
    }

    func testAllEnabledMatchesDefaultBehavior() {
        let input = "anna@example.com 192.168.1.25 DB_PASSWORD=secret"

        XCTAssertEqual(
            anonymizer.anonymize(input),
            anonymizer.anonymize(
                input,
                enabledCategories: ReplacementCategory.allCategories
            )
        )
    }

    func testNoEnabledCategoriesPreservesOutputButRetainsDetections() {
        let input = "Email: anna@example.com IP: 192.168.1.25 DB_PASSWORD=secret"
        let result = anonymizer.anonymizeWithResult(input, enabledCategories: [])

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertTrue(result.replacements.isEmpty)
        XCTAssertFalse(result.detectedItems.isEmpty)
        XCTAssertTrue(result.detectedItems.allSatisfy { !$0.isAnonymized })
    }

    func testNoEnabledCategoriesRetainsNaturalLanguageDetections() {
        let input = "John Smith works for Microsoft in Berlin."
        let result = anonymizer.anonymizeWithResult(input, enabledCategories: [])

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertTrue(result.detectedItems.contains { $0.category == .person })
        XCTAssertTrue(result.detectedItems.contains { $0.category == .organization })
        XCTAssertTrue(result.detectedItems.contains { $0.category == .location })
        XCTAssertTrue(result.detectedItems.allSatisfy { !$0.isAnonymized })
    }

    func testPreviewItemsShowDisabledDetectionsAndEnabledPlaceholders() {
        let input = "Email: anna@example.com URL: https://example.com"
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.email]
        )

        XCTAssertEqual(result.detectedItems.count, 2)
        XCTAssertEqual(result.detectedItems[0].category, .email)
        XCTAssertEqual(result.detectedItems[0].replacementValue, "[EMAIL_1]")
        XCTAssertEqual(result.detectedItems[1].category, .url)
        XCTAssertNil(result.detectedItems[1].replacementValue)
    }

    func testNaturalLanguageDetectsEnglishPersonOrganizationAndLocation() {
        let input = "John Smith works for OpenAI in New York."
        let matches = EntityDetector().detect(in: input)

        XCTAssertTrue(matches.contains {
            $0.category == .person && $0.originalValue == "John Smith"
        })
        XCTAssertTrue(matches.contains {
            $0.category == .organization && $0.originalValue == "OpenAI"
        })
        XCTAssertTrue(matches.contains {
            $0.category == .location && $0.originalValue == "New York"
        })
    }

    func testNaturalLanguageDetectsGermanPersonAndLocation() {
        let input = "Hallo, mein Name ist Julia Schneider. Ich arbeite in Münster."
        let matches = EntityDetector().detect(in: input)

        XCTAssertTrue(matches.contains {
            $0.category == .person && $0.originalValue == "Julia Schneider"
        })
        XCTAssertTrue(matches.contains {
            $0.category == .location && $0.originalValue == "Münster"
        })
    }

    func testGermanSalutationExpandsPartialPersonNameWithoutTitle() {
        let result = anonymizer.anonymizeWithResult("Guten Tag Frau Julia Schneider,")

        XCTAssertEqual(result.anonymizedText, "Guten Tag Frau [PERSON_1],")
        XCTAssertTrue(result.replacements.contains {
            $0.category == .person && $0.originalValue == "Julia Schneider"
        })
        XCTAssertFalse(result.replacements.contains {
            $0.originalValue == "Frau" || $0.originalValue == "Dr."
        })
    }

    func testGermanTitlesRemainVisibleForFullNames() {
        let input = "Herr Dr. Max Mustermann\nFrau Dr. Anna Müller"
        let result = anonymizer.anonymizeWithResult(input)

        XCTAssertTrue(result.anonymizedText.contains("Herr Dr. [PERSON_"))
        XCTAssertTrue(result.anonymizedText.contains("Frau Dr. [PERSON_"))
        XCTAssertFalse(result.anonymizedText.contains("[PERSON_1] Schneider"))
        XCTAssertFalse(result.replacements.contains { $0.originalValue == "Herr" })
        XCTAssertFalse(result.replacements.contains { $0.originalValue == "Frau" })
        XCTAssertFalse(result.replacements.contains { $0.originalValue == "Dr." })
    }

    func testCommonMailGreetingsAreNotEntityDetections() {
        let input = "Mit freundlichen Grüßen\nViele Grüße\nKind regards"
        let result = anonymizer.anonymizeWithResult(input)

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertFalse(result.detectedItems.contains {
            [.person, .organization, .location].contains($0.category)
        })
    }

    func testLegalCompanyFormProvidesConservativeOrganizationFallback() {
        let matches = EntityDetector().detect(in: "Mellowday Products GmbH")

        XCTAssertTrue(matches.contains {
            $0.category == .organization
                && $0.originalValue == "Mellowday Products GmbH"
                && $0.source == .fallbackRule
        })
    }

    func testStructuredAndAddressMatchesExposeSpecificSources() {
        let input = "Email anna@example.com, IP 192.168.1.25, address Musterstraße 12"
        let matches = PatternDetector().detect(in: input)

        XCTAssertEqual(
            matches.first { $0.category == .email }?.source,
            .structured
        )
        XCTAssertEqual(
            matches.first { $0.category == .ip }?.source,
            .structured
        )
        XCTAssertEqual(
            matches.first { $0.category == .address }?.source,
            .addressRule
        )
    }

    func testNaturalLanguageMatchesExposeNaturalLanguageSource() {
        let matches = EntityDetector().detect(in: "John Smith works for OpenAI in Berlin.")

        XCTAssertTrue(matches.contains { $0.originalValue == "John Smith" })
        XCTAssertTrue(matches.contains { $0.originalValue == "Berlin" })
        XCTAssertTrue(matches.allSatisfy { $0.source == .naturalLanguage })
    }

    func testDetectionSourceDisplayNamesAreUserFacingAndTyped() {
        XCTAssertEqual(DetectionSource.structured.displayName, "Structured")
        XCTAssertEqual(DetectionSource.naturalLanguage.displayName, "Natural Language")
        XCTAssertEqual(DetectionSource.localAI.displayName, "Local AI")
        XCTAssertEqual(DetectionSource.manual.displayName, "Manual")
        XCTAssertEqual(DetectionSource.addressRule.displayName, "Address Rule")
        XCTAssertEqual(DetectionSource.fallbackRule.displayName, "Fallback Rule")
    }

    func testSignatureBlockProvidesConservativePersonAndOrganizationFallbacks() {
        let input = """
        Anna Müller
        Mellowday Products GmbH
        Gartenstraße 27
        48143 Münster
        anna.mueller@mellowday-example.de
        +49 171 7654321
        """
        let result = anonymizer.anonymizeWithResult(input)

        XCTAssertTrue(result.replacements.contains {
            $0.category == .person && $0.originalValue == "Anna Müller"
        })
        XCTAssertTrue(result.replacements.contains {
            $0.category == .organization
                && $0.originalValue == "Mellowday Products GmbH"
        })
        XCTAssertTrue(result.replacements.contains {
            $0.category == .address
                && $0.originalValue == "Gartenstraße 27\n48143 Münster"
        })
    }

    func testRealWorldGermanEntityAndStructuredRegression() {
        let input = """
        Betreff: Rückfrage zu Ihrem Auftrag 4711

        Guten Tag Frau Julia Schneider,

        vielen Dank für Ihre Nachricht.

        Wir haben den Vorgang für die Smiles Consumer Goods GmbH geprüft. Die hinterlegte Anschrift lautet:

        Sonnenweg 12
        12345 Musterstadt

        Bei Rückfragen erreichen Sie Herrn Max Mustermann telefonisch unter +49 251 123456 oder per E-Mail unter max.mustermann@example.de.

        Das betroffene Kundensystem ist unter https://portal.smiles-example.de erreichbar. Die zugehörige Domain lautet smiles-example.de.

        Für die interne Prüfung wurde außerdem folgender Server verwendet:

        IP-Adresse: 192.168.1.25
        MAC-Adresse: 00:1A:2B:3C:4D:5E
        System-ID: 550e8400-e29b-41d4-a716-446655440000

        Die Test-Zugangsdaten aus der Konfiguration lauten:

        DB_PASSWORD=SuperSecret123!
        API_KEY=abcdef123456789
        Authorization: Bearer abc.def.ghi

        Die hinterlegte Bankverbindung lautet:

        DE89 3704 0044 0532 0130 00

        Bitte bestätigen Sie uns bis zum 21. August 2026, ob die oben genannten Angaben noch aktuell sind.

        Mit freundlichen Grüßen

        Anna Müller
        Mellowday Products GmbH
        Gartenstraße 27
        48143 Münster
        anna.mueller@mellowday-example.de
        +49 171 7654321
        """

        let result = anonymizer.anonymizeWithResult(input)
        let replacements = result.replacements

        XCTAssertTrue(replacements.contains {
            $0.category == .person && $0.originalValue == "Julia Schneider"
        })
        XCTAssertTrue(replacements.contains {
            $0.category == .person && $0.originalValue == "Max Mustermann"
        })
        XCTAssertTrue(replacements.contains {
            $0.category == .person && $0.originalValue == "Anna Müller"
        })
        XCTAssertTrue(replacements.contains {
            $0.category == .organization
                && $0.originalValue == "Mellowday Products GmbH"
        })
        XCTAssertTrue(replacements.contains {
            $0.category == .address
                && $0.originalValue == "Sonnenweg 12\n12345 Musterstadt"
        })
        XCTAssertFalse(result.anonymizedText.contains("Schneider"))
        XCTAssertTrue(result.anonymizedText.contains("Guten Tag Frau [PERSON_"))
        XCTAssertTrue(result.anonymizedText.contains("Mit freundlichen Grüßen"))

        for category in [
            ReplacementCategory.email,
            .phone,
            .url,
            .domain,
            .ip,
            .mac,
            .uuid,
            .secret,
            .token,
            .iban
        ] {
            XCTAssertTrue(
                replacements.contains { $0.category == category },
                "Expected a replacement for \(category)"
            )
        }
    }

    func testNaturalLanguageEntitiesUseCategoryPlaceholdersAndRepeatConsistently() {
        let input = "John Smith works for OpenAI in New York. John Smith is here."
        let result = anonymizer.anonymizeWithResult(input)

        XCTAssertEqual(
            result.anonymizedText,
            "[PERSON_1] works for [ORGANIZATION_1] in [LOCATION_1]. [PERSON_1] is here."
        )
        XCTAssertEqual(
            result.replacements.filter { $0.category == .person }.count,
            1
        )
        XCTAssertEqual(
            result.replacements.filter { $0.category == .organization }.count,
            1
        )
        XCTAssertEqual(
            result.replacements.filter { $0.category == .location }.count,
            1
        )
    }

    func testDisabledEntityCategoriesRemainVisibleButUnchanged() {
        let input = "John Smith works for Microsoft in Berlin."
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person]
        )

        XCTAssertEqual(
            result.anonymizedText,
            "[PERSON_1] works for Microsoft in Berlin."
        )

        let disabledItems = result.detectedItems.filter {
            $0.category == .organization || $0.category == .location
        }
        XCTAssertEqual(disabledItems.count, 2)
        XCTAssertTrue(disabledItems.allSatisfy { !$0.isAnonymized })
    }

    func testStructuredMatchesRemainMorePreciseThanNaturalLanguageEntities() {
        let input = "Contact john.smith@example.com or visit https://openai.com."
        let result = anonymizer.anonymizeWithResult(input)

        XCTAssertEqual(
            result.anonymizedText,
            "Contact [EMAIL_1] or visit [URL_1]."
        )
        XCTAssertFalse(result.detectedItems.contains { $0.category == .person })
        XCTAssertEqual(
            result.detectedItems.first { $0.category == .email }?.source,
            .structured
        )
        XCTAssertEqual(
            result.detectedItems.first { $0.category == .url }?.source,
            .structured
        )
    }

    func testNaturalLanguageCategoriesAreEnabledByDefaultAndIncludedInSelectAll() {
        XCTAssertTrue(ReplacementCategory.allCategories.contains(.person))
        XCTAssertTrue(ReplacementCategory.allCategories.contains(.organization))
        XCTAssertTrue(ReplacementCategory.allCategories.contains(.location))

        let result = anonymizer.anonymizeWithResult(
            "John Smith works for Microsoft in Berlin."
        )
        XCTAssertTrue(result.replacements.contains { $0.category == .person })
        XCTAssertTrue(result.replacements.contains { $0.category == .organization })
        XCTAssertTrue(result.replacements.contains { $0.category == .location })
    }

    func testProjectNamesBecomeOneFallbackCustomDetection() {
        let input = "Projekt Phoenix ist aktiv. Zum Projekt Phoenix gibt es weitere Hinweise."
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.custom, .person, .organization, .location]
        )

        XCTAssertEqual(
            result.anonymizedText,
            "[CUSTOM_1] ist aktiv. Zum [CUSTOM_1] gibt es weitere Hinweise."
        )
        XCTAssertEqual(
            result.replacements.filter { $0.category == .custom }.map(\.originalValue),
            ["Projekt Phoenix"]
        )
        XCTAssertTrue(
            result.detectedItems
                .filter { $0.originalValue == "Projekt Phoenix" }
                .allSatisfy { $0.category == .custom && $0.source == .fallbackRule }
        )
        XCTAssertFalse(result.detectedItems.contains { $0.originalValue == "Phoenix" })
    }

    func testUniquePersonFirstNameAliasReusesFullNameMapping() {
        let input = "Guten Tag Frau Julia Schneider, bitte geben Sie Julia anschließend Bescheid."
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person]
        )

        XCTAssertEqual(
            result.anonymizedText,
            "Guten Tag Frau [PERSON_1], bitte geben Sie [PERSON_1] anschließend Bescheid."
        )
        XCTAssertTrue(
            result.detectedItems.contains {
                $0.originalValue == "Julia"
                    && $0.category == .person
                    && $0.source == .fallbackRule
                    && $0.replacementValue == "[PERSON_1]"
            }
        )
    }

    func testAmbiguousFirstNameDoesNotReceiveFallbackAlias() {
        let input = "Frau Julia Schneider und Herr Julia Müller. Danach: Julia."
        let matches = EntityDetector().detect(in: input)

        XCTAssertFalse(matches.contains {
            $0.originalValue == "Julia"
                && $0.source == .fallbackRule
        })
    }

    func testEmbeddedLegalFormOrganizationUsesFallbackSource() {
        let input = "Zusätzlich war Søren Nielsen von der Mellowday Products GmbH beteiligt."
        let matches = EntityDetector().detect(in: input)

        XCTAssertTrue(matches.contains {
            $0.originalValue == "Mellowday Products GmbH"
                && $0.category == .organization
                && $0.source == .fallbackRule
        })
        XCTAssertFalse(matches.contains { $0.originalValue == "von der Mellowday Products GmbH" })
    }

    func testProjectAliasAndFlowingOrganizationRegression() {
        let input = """
        Betreff: Abstimmung zum Projekt Phoenix und Kundensystem

        Guten Tag Frau Julia Schneider,

        Zusätzlich war Søren Nielsen von der Mellowday Products GmbH beteiligt.

        Für Rückfragen zum Projekt Phoenix wenden Sie sich bitte an Julia.
        """
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.custom, .person, .organization]
        )

        let projectReplacements = result.replacements.filter { $0.category == .custom }
        XCTAssertEqual(projectReplacements.count, 1)
        XCTAssertEqual(projectReplacements.first?.originalValue, "Projekt Phoenix")
        XCTAssertTrue(
            result.detectedItems
                .filter { $0.originalValue == "Projekt Phoenix" }
                .allSatisfy { $0.category == .custom && $0.source == .fallbackRule }
        )
        XCTAssertTrue(
            result.replacements.contains {
                $0.category == .person && $0.originalValue == "Julia Schneider"
            }
        )
        XCTAssertTrue(
            result.replacements.contains {
                $0.category == .organization
                    && $0.originalValue == "Mellowday Products GmbH"
            }
        )
        XCTAssertTrue(result.anonymizedText.contains("Guten Tag Frau [PERSON_"))
        XCTAssertFalse(result.anonymizedText.contains("Julia."))
    }

    func testDetectionHighlightsRepresentActiveAndDisabledEffectiveItems() throws {
        let input = "anna@example.com 192.168.1.25"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.email, .ip]
        )
        let emailID = try XCTUnwrap(
            initialResult.detectedItems.first { $0.category == .email }?.id
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.email, .ip],
            selectedDetectionIDs: [emailID]
        )

        XCTAssertEqual(result.detectionHighlights.count, 2)
        XCTAssertTrue(result.detectionHighlights.contains { $0.isActive && $0.range.location == 0 })
        let ipLocation = NSRange(
            input.range(of: "192.168.1.25")!,
            in: input
        ).location
        XCTAssertTrue(
            result.detectionHighlights.contains {
                !$0.isActive && $0.range.location == ipLocation
            }
        )
        XCTAssertTrue(result.detectionHighlights(for: .stale).isEmpty)
        XCTAssertTrue(result.detectionHighlights(for: .idle).isEmpty)
    }

    func testManualDetectionIsIncludedInHighlightDescriptors() throws {
        let input = "Hallo Julia"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(input.range(of: "Julia")!, in: input),
                category: .person
            )
        )
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person],
            manualDetections: [manualDetection]
        )

        XCTAssertEqual(result.detectionHighlights.count, 1)
        XCTAssertTrue(result.detectionHighlights.first?.isActive == true)
    }

    func testIndividualDomainSelectionAnonymizesOnlySelectedDetection() throws {
        let input = "Documentation: openai.com Customer: private-customer.de"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain]
        )
        let customerDomainID = try XCTUnwrap(
            initialResult.detectedItems.first { $0.originalValue == "private-customer.de" }?.id
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain],
            selectedDetectionIDs: [customerDomainID]
        )

        XCTAssertEqual(
            result.anonymizedText,
            "Documentation: openai.com Customer: [DOMAIN_1]"
        )
        XCTAssertNil(result.detectedItems.first { $0.originalValue == "openai.com" }?.replacementValue)
        XCTAssertEqual(
            result.detectedItems.first { $0.originalValue == "private-customer.de" }?.replacementValue,
            "[DOMAIN_1]"
        )
    }

    func testRepeatedDomainOccurrencesCanBeSelectedIndependently() throws {
        let input = "openai.com openai.com"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain]
        )
        let domainIDs = initialResult.detectedItems.map(\.id)
        XCTAssertEqual(domainIDs.count, 2)

        let firstOnly = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain],
            selectedDetectionIDs: [try XCTUnwrap(domainIDs.first)]
        )
        XCTAssertEqual(firstOnly.anonymizedText, "[DOMAIN_1] openai.com")

        let secondOnly = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain],
            selectedDetectionIDs: [try XCTUnwrap(domainIDs.last)]
        )
        XCTAssertEqual(secondOnly.anonymizedText, "openai.com [DOMAIN_1]")
    }

    func testDisabledIndividualDetectionsDoNotConsumePlaceholderNumbers() throws {
        let input = "one.example.com two.example.com three.example.com"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain]
        )
        let selectedIDs = Set(initialResult.detectedItems.dropFirst().map(\.id))

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain],
            selectedDetectionIDs: selectedIDs
        )

        XCTAssertEqual(
            result.anonymizedText,
            "one.example.com [DOMAIN_1] [DOMAIN_2]"
        )
        XCTAssertEqual(
            result.replacements.map(\.replacementValue),
            ["[DOMAIN_1]", "[DOMAIN_2]"]
        )
    }

    func testGloballyDisabledCategoryOverridesIndividualSelection() throws {
        let input = "openai.com private-customer.de"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain]
        )
        let allIDs = Set(initialResult.detectedItems.map(\.id))

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [],
            selectedDetectionIDs: allIDs
        )

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertTrue(result.detectedItems.allSatisfy { !$0.isAnonymized })
    }

    func testReenabledCategoryUsesCurrentIndividualSelection() throws {
        let input = "openai.com private-customer.de"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain]
        )
        let selectedID = try XCTUnwrap(
            initialResult.detectedItems.first { $0.originalValue == "private-customer.de" }?.id
        )

        let disabledResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [],
            selectedDetectionIDs: [selectedID]
        )
        XCTAssertEqual(disabledResult.anonymizedText, input)

        let reenabledResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.domain],
            selectedDetectionIDs: [selectedID]
        )
        XCTAssertEqual(
            reenabledResult.anonymizedText,
            "openai.com [DOMAIN_1]"
        )
    }

    func testGermanPostalAddressesAreAnonymizedAsCompleteMatches() {
        let input = "Musterstraße 12, 12345 Musterstadt\nGartenstraße 27, 48143 Münster\nLichtweg 6, 04109 Leipzig\nSonnenweg 12\nHauptstraße 15a"
        let expected = "[ADDRESS_1]\n[ADDRESS_2]\n[ADDRESS_3]\n[ADDRESS_4]\n[ADDRESS_5]"

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: [.address]),
            expected
        )
    }

    func testMultilineAddressIsOneDetection() {
        let input = "Shipping:\nMusterstraße 12\n12345 Musterstadt."
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.address]
        )

        XCTAssertEqual(result.anonymizedText, "Shipping:\n[ADDRESS_1].")
        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.category, .address)
    }

    func testAddressPunctuationIsPreserved() {
        let input = "(Musterstraße 12, 12345 Musterstadt)."
        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: [.address]),
            "([ADDRESS_1])."
        )
    }

    func testRepeatedAddressesSharePlaceholderWhenBothAreSelected() {
        let input = "Musterstraße 12, 12345 Musterstadt; Musterstraße 12, 12345 Musterstadt"
        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: [.address]),
            "[ADDRESS_1]; [ADDRESS_1]"
        )
    }

    func testRepeatedAddressesCanBeSelectedIndependently() throws {
        let input = "Musterstraße 12, 12345 Musterstadt\nMusterstraße 12, 12345 Musterstadt"
        let initialResult = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.address]
        )
        let firstID = try XCTUnwrap(initialResult.detectedItems.first?.id)

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.address],
            selectedDetectionIDs: [firstID]
        )

        XCTAssertEqual(result.anonymizedText, "[ADDRESS_1]\nMusterstraße 12, 12345 Musterstadt")
    }

    func testAddressFalsePositivesRemainUnchanged() {
        let input = "Server 12\nVersion 15\nPort 8080\nTicket 12345\nBuild 27\n48143"

        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: [.address]),
            input
        )
    }

    func testAddressTakesPrecedenceOverContainedLocation() {
        let input = "Musterstraße 12, 48143 Münster"
        let result = anonymizer.anonymizeWithResult(input)

        XCTAssertEqual(result.anonymizedText, "[ADDRESS_1]")
        XCTAssertFalse(result.detectedItems.contains { $0.category == .location })
    }

    func testAddressCategoryIsEnabledByDefault() {
        XCTAssertTrue(ReplacementCategory.allCategories.contains(.address))
        XCTAssertEqual(
            anonymizer.anonymize("Musterstraße 12"),
            "[ADDRESS_1]"
        )
    }

    func testCombinedTechnicalInputIncludesAddressAndExistingCategories() {
        let input = """
        Example GmbH
        Musterstraße 12
        12345 Musterstadt

        Contact:
        max.mustermann@example.com
        +49 251 123456

        Customer portal:
        https://customer.example.com

        Documentation:
        openai.com

        Server:
        192.168.1.25

        DB_PASSWORD=SuperSecret123!
        """
        let expected = """
        Example GmbH
        [ADDRESS_1]

        Contact:
        [EMAIL_1]
        [PHONE_1]

        Customer portal:
        [URL_1]

        Documentation:
        [DOMAIN_1]

        Server:
        [IP_1]

        DB_PASSWORD=[SECRET_1]
        """

        let structuredCategories: Set<ReplacementCategory> = [
            .address, .email, .phone, .url, .domain, .ip, .secret
        ]
        XCTAssertEqual(
            anonymizer.anonymize(input, enabledCategories: structuredCategories),
            expected
        )
    }

    func testManualPersonSelectionAnonymizesAFirstName() throws {
        let input = "Hallo Julia"
        let selectedRange = NSRange(
            input.range(of: "Julia")!,
            in: input
        )
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: selectedRange,
                category: .person
            )
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person],
            manualDetections: [manualDetection]
        )

        XCTAssertEqual(result.anonymizedText, "Hallo [PERSON_1]")
        XCTAssertEqual(result.detectedItems.first?.source, .manual)
    }

    func testManualCustomSelectionUsesCustomPlaceholder() throws {
        let input = "Projekt Phoenix"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 0, length: input.utf16.count),
                category: .custom
            )
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.custom],
            manualDetections: [manualDetection]
        )

        XCTAssertEqual(result.anonymizedText, "[CUSTOM_1]")
        XCTAssertEqual(result.replacements.first?.category, .custom)
    }

    func testManualCustomMappingRestoresThroughExistingWorkflow() throws {
        let input = "Hallo Julia"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 6, length: 5),
                category: .person
            )
        )
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person],
            manualDetections: [manualDetection]
        )

        let session = AnonymizationSession(result: result)
        let restored = Restorer().restore(
            "Guten Morgen [PERSON_1]",
            using: session
        )

        XCTAssertEqual(restored.restoredText, "Guten Morgen Julia")
    }

    func testManualCustomMappingRestoresCustomPlaceholder() throws {
        let input = "Projekt Phoenix"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 0, length: input.utf16.count),
                category: .custom
            )
        )
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.custom],
            manualDetections: [manualDetection]
        )

        let restored = Restorer().restore(
            "Das betrifft [CUSTOM_1].",
            using: AnonymizationSession(result: result)
        )

        XCTAssertEqual(restored.restoredText, "Das betrifft Projekt Phoenix.")
    }

    func testManualDetectionWinsOverAutomaticDetectionForSameRange() throws {
        let input = "John Smith"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 0, length: input.utf16.count),
                category: .custom
            )
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            manualDetections: [manualDetection]
        )

        XCTAssertEqual(result.anonymizedText, "[CUSTOM_1]")
        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.source, .manual)
    }

    func testManualDetectionCanBeIndividuallyDisabled() throws {
        let input = "Hallo Julia"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 6, length: 5),
                category: .person
            )
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person],
            selectedDetectionIDs: [],
            manualDetections: [manualDetection]
        )

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertNil(result.detectedItems.first?.replacementValue)
        XCTAssertTrue(result.replacements.isEmpty)
    }

    func testGlobalCategoryDisableOverridesManualSelection() throws {
        let input = "Projekt Phoenix"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 0, length: input.utf16.count),
                category: .custom
            )
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [],
            selectedDetectionIDs: [manualDetection.id],
            manualDetections: [manualDetection]
        )

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertTrue(result.replacements.isEmpty)
    }

    func testRepeatedManualValuesSharePlaceholderButOccurrencesRemainSelectable() throws {
        let input = "Julia Julia"
        let first = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 0, length: 5),
                category: .custom
            )
        )
        let second = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 6, length: 5),
                category: .custom
            )
        )

        let both = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.custom],
            manualDetections: [first, second]
        )
        let firstOnly = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.custom],
            selectedDetectionIDs: [first.id],
            manualDetections: [first, second]
        )

        XCTAssertEqual(both.anonymizedText, "[CUSTOM_1] [CUSTOM_1]")
        XCTAssertEqual(firstOnly.anonymizedText, "[CUSTOM_1] Julia")
    }

    func testRemovingManualDetectionAllowsAutomaticDetectionToResume() throws {
        let input = "John Smith"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 0, length: input.utf16.count),
                category: .custom
            )
        )

        let withManual = anonymizer.anonymizeWithResult(
            input,
            manualDetections: [manualDetection]
        )
        let afterRemoval = anonymizer.anonymizeWithResult(input)

        XCTAssertEqual(withManual.anonymizedText, "[CUSTOM_1]")
        XCTAssertNotEqual(afterRemoval.anonymizedText, withManual.anonymizedText)
        XCTAssertTrue(afterRemoval.detectedItems.contains { $0.category == .person })
    }

    func testManualDetectionIsDiscardedWhenSourceTextChanges() throws {
        let original = "Hallo Julia"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: original,
                sourceRange: NSRange(location: 6, length: 5),
                category: .custom
            )
        )

        XCTAssertNil(manualDetection.match(in: "Hallo Maria"))
        let result = anonymizer.anonymizeWithResult(
            "Hallo Maria",
            enabledCategories: [.custom],
            manualDetections: [manualDetection]
        )
        XCTAssertEqual(result.anonymizedText, "Hallo Maria")
    }

    func testSuppliedAnalysisMatchesPreventImplicitRedetection() {
        let input = "Contact anna@example.com"
        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.email],
            detectedMatches: []
        )

        XCTAssertEqual(result.anonymizedText, input)
        XCTAssertTrue(result.detectedItems.isEmpty)
    }

    func testManualDetectionCanBeAddedAfterAnalysisWithoutRedetection() throws {
        let input = "Hallo Julia"
        let manualDetection = try XCTUnwrap(
            ManualDetection(
                text: input,
                sourceRange: NSRange(location: 6, length: 5),
                category: .person
            )
        )

        let result = anonymizer.anonymizeWithResult(
            input,
            enabledCategories: [.person],
            manualDetections: [manualDetection],
            detectedMatches: []
        )

        XCTAssertEqual(result.anonymizedText, "Hallo [PERSON_1]")
        XCTAssertEqual(result.detectedItems.count, 1)
        XCTAssertEqual(result.detectedItems.first?.source, .manual)
    }

    func testAnalysisStateIsEquatableForExplicitWorkflowStates() {
        XCTAssertEqual(AnalysisState.idle, .idle)
        XCTAssertNotEqual(AnalysisState.idle, .stale)
        XCTAssertNotEqual(AnalysisState.analyzing, .complete)
    }

    func testEmptyLocalAIAnalysisIsHarmless() async {
        let result = await LocalAIDetector().detect(in: "")

        XCTAssertTrue(result.matches.isEmpty)
    }

    func testLocalAIAvailabilityMessagesRemainSpecific() {
        XCTAssertTrue(LocalAIAvailability.available.isAvailable)
        XCTAssertEqual(LocalAIAvailability.available.displayName, "Available")

        XCTAssertFalse(LocalAIAvailability.appleIntelligenceNotEnabled.isAvailable)
        XCTAssertTrue(
            LocalAIAvailability.appleIntelligenceNotEnabled.detail.contains(
                "not enabled"
            )
        )
        XCTAssertTrue(LocalAIAvailability.appleIntelligenceNotEnabled.canOpenSystemSettings)

        XCTAssertTrue(
            LocalAIAvailability.deviceNotEligible.detail.contains(
                "does not support"
            )
        )
        XCTAssertFalse(LocalAIAvailability.deviceNotEligible.canOpenSystemSettings)

        XCTAssertTrue(
            LocalAIAvailability.modelNotReady.detail.contains(
                "not ready"
            )
        )
        XCTAssertTrue(
            LocalAIAvailability.unsupportedOS.detail.contains(
                "macOS 26"
            )
        )
    }

    func testLocalAICandidateMapperValidatesExactSourceOccurrences() {
        let input = "Hallo Julia. Julia arbeitet bei Example GmbH."
        let candidates = [
            LocalAICandidate(value: "Julia", category: .person),
            LocalAICandidate(value: "Example GmbH", category: .organization),
            LocalAICandidate(value: "Not in source", category: .person),
            LocalAICandidate(value: "Julia", category: .email)
        ]

        let matches = LocalAICandidateMapper.matches(from: candidates, in: input)

        XCTAssertEqual(
            matches.map(\.originalValue),
            ["Julia", "Julia", "Example GmbH"]
        )
        XCTAssertTrue(matches.allSatisfy { $0.source == .localAI })
        XCTAssertTrue(matches.allSatisfy { input[$0.sourceRange] == $0.originalValue })
    }

    func testLocalAIDetectionsAreOptionalAndDoNotChangeTheDefaultPipeline() {
        let input = "Hallo Julia"
        let withoutLocalAI = anonymizer.anonymizeWithResult(input)
        let withNoLocalAICandidates = anonymizer.anonymizeWithResult(
            input,
            localAIDetections: []
        )

        XCTAssertEqual(withoutLocalAI.anonymizedText, withNoLocalAICandidates.anonymizedText)
        XCTAssertEqual(withoutLocalAI.detectedItems, withNoLocalAICandidates.detectedItems)
    }
}
