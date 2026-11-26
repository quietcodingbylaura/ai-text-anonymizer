import Foundation
import NaturalLanguage

struct EntityDetector {
    func detect(in text: String) -> [DetectedMatch] {
        guard !text.isEmpty else {
            return []
        }

        let greetingRanges = greetingRanges(in: text)
        let projectMatches = projectNameFallbackMatches(in: text)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var matches = projectMatches
        let fullRange = text.startIndex..<text.endIndex

        tagger.enumerateTags(
            in: fullRange,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, tokenRange in
            guard let tag,
                  let category = category(for: tag),
                  let entityRange = trimmedEntityRange(tokenRange, in: text) else {
                return true
            }

            guard !greetingRanges.contains(where: { rangesOverlap($0, entityRange) }) else {
                return true
            }

            // A project name is a deliberately narrow CUSTOM fallback. Do not
            // let NaturalLanguage split the same phrase into unrelated entities.
            guard !projectMatches.contains(where: { rangesOverlap($0.sourceRange, entityRange) }) else {
                return true
            }

            if category == .person {
                guard let personMatch = expandedPersonMatch(in: text, range: entityRange) else {
                    return true
                }
                appendIfUnique(personMatch, to: &matches)
            } else {
                let value = String(text[entityRange])
                guard !isExcludedTitle(value) else {
                    return true
                }

                appendIfUnique(
                    DetectedMatch(
                        originalValue: value,
                        category: category,
                        sourceRange: entityRange,
                        normalizedValue: value,
                        source: .naturalLanguage
                    ),
                    to: &matches
                )
            }
            return true
        }

        for fallback in salutationPersonFallbackMatches(in: text) {
            appendIfUnique(fallback, to: &matches)
        }

        for fallback in signatureFallbackMatches(in: text, existingMatches: matches) {
            appendIfUnique(fallback, to: &matches)
        }

        // A unique, previously identified full name may provide a conservative
        // first-name alias later in the same text. Ambiguous first names remain
        // untouched. Alias matches inherit the full name's mapping identity.
        for alias in personAliasMatches(in: text, from: matches) {
            matches.removeAll { rangesOverlap($0.sourceRange, alias.sourceRange) }
            appendIfUnique(alias, to: &matches)
        }

        return matches
    }

    private func expandedPersonMatch(
        in text: String,
        range: Range<String.Index>
    ) -> DetectedMatch? {
        var expandedRange = range

        if let nameRange = removingLeadingTitle(from: expandedRange, in: text) {
            expandedRange = nameRange
        }

        if let nameRange = removingLeadingPronoun(from: expandedRange, in: text) {
            expandedRange = nameRange
        }

        if hasGermanSalutationImmediatelyBefore(expandedRange.lowerBound, in: text),
           let surnameRange = nextNameWordRange(after: expandedRange.upperBound, in: text) {
            expandedRange = expandedRange.lowerBound..<surnameRange.upperBound
        }

        let value = String(text[expandedRange])
        guard !isExcludedTitle(value) else {
            return nil
        }

        return DetectedMatch(
            originalValue: value,
            category: .person,
            sourceRange: expandedRange,
            normalizedValue: value,
            source: .naturalLanguage
        )
    }

    private func removingLeadingTitle(
        from range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index>? {
        let value = String(text[range])
        guard let titleMatch = Self.leadingTitleRegex.firstMatch(
            in: value,
            range: NSRange(location: 0, length: value.utf16.count)
        ),
        titleMatch.range.location == 0,
        let titleRange = Range(titleMatch.range, in: value) else {
            return nil
        }

        let offset = value.distance(from: value.startIndex, to: titleRange.upperBound)
        let nameStart = text.index(range.lowerBound, offsetBy: offset)
        guard nameStart < range.upperBound else {
            return nil
        }
        return nameStart..<range.upperBound
    }

    private func removingLeadingPronoun(
        from range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index>? {
        let value = String(text[range])
        let words = value.split(whereSeparator: \.isWhitespace)
        guard words.count >= 2,
              words.first?.lowercased() == "sie",
              words.dropFirst().allSatisfy({ isLikelyNameWord(String($0)) }) else {
            return nil
        }

        guard let firstNameStart = value.firstIndex(where: { !$0.isWhitespace }) else {
            return nil
        }
        var nameStart = firstNameStart
        while nameStart < value.endIndex, !value[nameStart].isWhitespace {
            nameStart = value.index(after: nameStart)
        }
        guard nameStart < value.endIndex else {
            return nil
        }
        while nameStart < value.endIndex, value[nameStart].isWhitespace {
            nameStart = value.index(after: nameStart)
        }
        guard nameStart < value.endIndex else {
            return nil
        }
        let offset = value.distance(from: value.startIndex, to: nameStart)
        let textNameStart = text.index(range.lowerBound, offsetBy: offset)
        return textNameStart..<range.upperBound
    }

    private func hasGermanSalutationImmediatelyBefore(
        _ position: String.Index,
        in text: String
    ) -> Bool {
        let lineStart = text[..<position].lastIndex(of: "\n").map {
            text.index(after: $0)
        } ?? text.startIndex
        let prefix = String(text[lineStart..<position])

        return Self.salutationBeforePersonRegex.firstMatch(
            in: prefix,
            range: NSRange(location: 0, length: prefix.utf16.count)
        ) != nil
    }

    private func nextNameWordRange(
        after position: String.Index,
        in text: String
    ) -> Range<String.Index>? {
        var start = position
        while start < text.endIndex, text[start] == " " || text[start] == "\t" {
            start = text.index(after: start)
        }

        guard start < text.endIndex else {
            return nil
        }

        var end = start
        while end < text.endIndex, isNameWordCharacter(text[end]) {
            end = text.index(after: end)
        }

        guard end > start else {
            return nil
        }

        let value = String(text[start..<end])
        guard isLikelyNameWord(value) else {
            return nil
        }
        return start..<end
    }

    private func signatureFallbackMatches(
        in text: String,
        existingMatches: [DetectedMatch]
    ) -> [DetectedMatch] {
        let lines = lineInfos(in: text)
        var fallbackMatches: [DetectedMatch] = []

        for organizationMatch in flowingLegalOrganizationMatches(in: text) {
            appendIfUnique(organizationMatch, to: &fallbackMatches)
        }

        for line in lines {
            guard let organizationMatch = legalOrganizationMatch(for: line) else {
                continue
            }
            appendIfUnique(organizationMatch, to: &fallbackMatches)
        }

        for (index, line) in lines.enumerated() {
            guard let nameMatch = signaturePersonMatch(for: line),
                  hasSignatureContext(around: index, lines: lines) else {
                continue
            }
            appendIfUnique(nameMatch, to: &fallbackMatches)
        }

        return fallbackMatches.filter { candidate in
            !existingMatches.contains {
                $0.category == candidate.category && $0.sourceRange == candidate.sourceRange
            }
        }
    }

    private func flowingLegalOrganizationMatches(in text: String) -> [DetectedMatch] {
        Self.flowingLegalOrganizationRegex.matches(
            in: text,
            range: NSRange(location: 0, length: text.utf16.count)
        ).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            let value = String(text[range])
            return DetectedMatch(
                originalValue: value,
                category: .organization,
                sourceRange: range,
                normalizedValue: normalizedEntityValue(value),
                source: .fallbackRule
            )
        }
    }

    private func projectNameFallbackMatches(in text: String) -> [DetectedMatch] {
        Self.projectNameRegex.matches(
            in: text,
            range: NSRange(location: 0, length: text.utf16.count)
        ).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            let value = String(text[range])
            return DetectedMatch(
                originalValue: value,
                category: .custom,
                sourceRange: range,
                normalizedValue: normalizedEntityValue(value),
                source: .fallbackRule
            )
        }
    }

    private func personAliasMatches(
        in text: String,
        from matches: [DetectedMatch]
    ) -> [DetectedMatch] {
        var peopleByFirstName: [String: [(identity: String, match: DetectedMatch)]] = [:]

        for match in matches where match.category == .person {
            let words = String(match.originalValue)
                .split(whereSeparator: \.isWhitespace)
            guard words.count >= 2, let firstName = words.first else {
                continue
            }

            let firstNameKey = String(firstName).lowercased()
            let identity = normalizedEntityValue(match.originalValue)
            peopleByFirstName[firstNameKey, default: []].append((identity, match))
        }

        var aliases: [DetectedMatch] = []
        for (firstNameKey, candidates) in peopleByFirstName {
            let identities = Set(candidates.map(\.identity))
            guard identities.count == 1,
                  let representative = candidates.first?.match else {
                continue
            }

            let firstName = String(representative.originalValue)
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init) ?? firstNameKey
            var searchStart = text.startIndex

            while searchStart < text.endIndex,
                  let range = text.range(
                      of: firstName,
                      options: [.caseInsensitive],
                      range: searchStart..<text.endIndex
                  ) {
                let occursAfterFullName = candidates.contains {
                    $0.match.sourceRange.upperBound <= range.lowerBound
                }
                let isAlreadyPartOfFullName = matches.contains {
                    $0.category == .person
                        && isFullPersonMatch($0)
                        && rangesOverlap($0.sourceRange, range)
                }

                if occursAfterFullName,
                   !isAlreadyPartOfFullName,
                   isStandaloneNameRange(range, in: text) {
                    aliases.append(
                        DetectedMatch(
                            originalValue: String(text[range]),
                            category: .person,
                            sourceRange: range,
                            normalizedValue: representative.normalizedValue,
                            source: .fallbackRule
                        )
                    )
                }

                guard range.upperBound < text.endIndex else {
                    break
                }
                searchStart = range.upperBound
            }
        }

        return aliases
    }

    private func isFullPersonMatch(_ match: DetectedMatch) -> Bool {
        String(match.originalValue)
            .split(whereSeparator: \.isWhitespace)
            .count >= 2
    }

    private func isStandaloneNameRange(
        _ range: Range<String.Index>,
        in text: String
    ) -> Bool {
        if range.lowerBound > text.startIndex {
            let previous = text.index(before: range.lowerBound)
            guard isAliasBoundaryCharacter(text[previous]) else {
                return false
            }
        }

        if range.upperBound < text.endIndex {
            guard isAliasBoundaryCharacter(text[range.upperBound]) else {
                return false
            }
        }

        return true
    }

    private func isAliasBoundaryCharacter(_ character: Character) -> Bool {
        !character.isLetter
            && !character.isNumber
            && character != "-"
            && character != "'"
            && character != "’"
    }

    private func normalizedEntityValue(_ value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func salutationPersonFallbackMatches(in text: String) -> [DetectedMatch] {
        Self.salutationPersonRegex.matches(
            in: text,
            range: NSRange(location: 0, length: text.utf16.count)
        ).compactMap { result in
            let nameRange = result.range(at: 1)
            guard nameRange.location != NSNotFound,
                  let range = Range(nameRange, in: text) else {
                return nil
            }

            let value = String(text[range])
            return DetectedMatch(
                originalValue: value,
                category: .person,
                sourceRange: range,
                normalizedValue: value,
                source: .fallbackRule
            )
        }
    }

    private func legalOrganizationMatch(for line: LineInfo) -> DetectedMatch? {
        guard !isGreetingPhrase(line.value),
              let legalFormMatch = Self.legalFormRegex.firstMatch(
                  in: line.value,
                  range: NSRange(location: 0, length: line.value.utf16.count)
              ),
              let legalFormRange = Range(legalFormMatch.range, in: line.value) else {
            return nil
        }

        let companyName = line.value[..<legalFormRange.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        guard !companyName.isEmpty,
              companyName.split(whereSeparator: \.isWhitespace).count <= 8,
              companyName.allSatisfy({ character in
                  character.isLetter
                      || character.isNumber
                      || character.isWhitespace
                      || "&.'’+-".contains(character)
              }) else {
            return nil
        }

        return DetectedMatch(
            originalValue: line.value,
            category: .organization,
            sourceRange: line.range,
            normalizedValue: line.value,
            source: .fallbackRule
        )
    }

    private func signaturePersonMatch(for line: LineInfo) -> DetectedMatch? {
        guard !isGreetingPhrase(line.value) else {
            return nil
        }

        let words = line.value.split(whereSeparator: \.isWhitespace)
        guard (2...3).contains(words.count),
              words.allSatisfy({ isLikelyNameWord(String($0)) }) else {
            return nil
        }

        return DetectedMatch(
            originalValue: line.value,
            category: .person,
            sourceRange: line.range,
            normalizedValue: line.value,
            source: .fallbackRule
        )
    }

    private func hasSignatureContext(
        around index: Int,
        lines: [LineInfo]
    ) -> Bool {
        if index > 0, isGreetingPhrase(lines[index - 1].value) {
            return true
        }

        let end = min(lines.count, index + 5)
        for followingLine in lines[(index + 1)..<end] {
            if legalOrganizationMatch(for: followingLine) != nil
                || lineLooksLikeAddress(followingLine.value)
                || lineContainsEmailOrPhone(followingLine.value) {
                return true
            }
        }
        return false
    }

    private func lineInfos(in text: String) -> [LineInfo] {
        var lines: [LineInfo] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            guard let trimmedRange = trimmedLineRange(lineRange, in: text) else {
                return
            }
            lines.append(
                LineInfo(
                    range: trimmedRange,
                    value: String(text[trimmedRange])
                )
            )
        }
        return lines
    }

    private func trimmedLineRange(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index>? {
        var lowerBound = range.lowerBound
        var upperBound = range.upperBound

        while lowerBound < upperBound, text[lowerBound].isWhitespace {
            lowerBound = text.index(after: lowerBound)
        }
        while upperBound > lowerBound, text[text.index(before: upperBound)].isWhitespace {
            upperBound = text.index(before: upperBound)
        }

        return lowerBound < upperBound ? lowerBound..<upperBound : nil
    }

    private func lineLooksLikeAddress(_ value: String) -> Bool {
        Self.streetLineRegex.firstMatch(
            in: value,
            range: NSRange(location: 0, length: value.utf16.count)
        ) != nil
    }

    private func lineContainsEmailOrPhone(_ value: String) -> Bool {
        let digitCount = value.filter(\.isNumber).count
        return (value.contains("@") && value.contains("."))
            || (digitCount >= 7 && (value.contains("+") || value.hasPrefix("00")))
    }

    private func greetingRanges(in text: String) -> [Range<String.Index>] {
        Self.greetingRegex.matches(
            in: text,
            range: NSRange(location: 0, length: text.utf16.count)
        ).compactMap { Range($0.range, in: text) }
    }

    private func isGreetingPhrase(_ value: String) -> Bool {
        Self.greetingRegex.firstMatch(
            in: value,
            range: NSRange(location: 0, length: value.utf16.count)
        ) != nil
    }

    private func isExcludedTitle(_ value: String) -> Bool {
        ["herr", "herrn", "frau", "dr", "dr."]
            .contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private func isLikelyNameWord(_ value: String) -> Bool {
        guard let first = value.first,
              first.isUppercase,
              value.count >= 2 else {
            return false
        }
        return value.allSatisfy(isNameWordCharacter)
    }

    private func isNameWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "-" || character == "'" || character == "’"
    }

    private func appendIfUnique(_ match: DetectedMatch, to matches: inout [DetectedMatch]) {
        guard !matches.contains(where: {
            $0.category == match.category && $0.sourceRange == match.sourceRange
        }) else {
            return
        }
        matches.append(match)
    }

    private func rangesOverlap(
        _ first: Range<String.Index>,
        _ second: Range<String.Index>
    ) -> Bool {
        first.lowerBound < second.upperBound && second.lowerBound < first.upperBound
    }

    private struct LineInfo {
        let range: Range<String.Index>
        let value: String
    }

    private func category(for tag: NLTag) -> ReplacementCategory? {
        switch tag {
        case .personalName:
            .person
        case .organizationName:
            .organization
        case .placeName:
            .location
        default:
            nil
        }
    }

    private func trimmedEntityRange(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index>? {
        var lowerBound = range.lowerBound
        var upperBound = range.upperBound

        while lowerBound < upperBound {
            guard isBoundaryCharacter(text[lowerBound]) else {
                break
            }
            lowerBound = text.index(after: lowerBound)
        }

        while upperBound > lowerBound {
            let previous = text.index(before: upperBound)
            guard isBoundaryCharacter(text[previous]) else {
                break
            }
            upperBound = previous
        }

        guard lowerBound < upperBound else {
            return nil
        }
        return lowerBound..<upperBound
    }

    private func isBoundaryCharacter(_ character: Character) -> Bool {
        String(character).unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.punctuationCharacters.contains(scalar)
        }
    }

    private static let greetingRegex = makeRegex(
        #"(?i)(?<![A-Za-zÄÖÜäöüß])(?:mit[ \t]+freundlichen[ \t]+grüßen|mit[ \t]+besten[ \t]+grüßen|viele[ \t]+grüße|freundliche[ \t]+grüße|beste[ \t]+grüße|herzliche[ \t]+grüße|liebe[ \t]+grüße|kind[ \t]+regards|best[ \t]+regards|warm[ \t]+regards|sincerely|yours[ \t]+sincerely|yours[ \t]+faithfully)(?![A-Za-zÄÖÜäöüß])"#
    )

    private static let leadingTitleRegex = makeRegex(
        #"(?i)^(?:(?:Herr|Herrn|Frau)(?:[ \t]+Dr\.)?|Dr\.)[ \t]+"#
    )

    private static let salutationBeforePersonRegex = makeRegex(
        #"(?i)(?:^|[^A-Za-zÄÖÜäöüß])(?:Herr|Herrn|Frau)(?:[ \t]+Dr\.)?[ \t]+$"#
    )

    private static let salutationPersonRegex = makeRegex(
        #"(?<![A-Za-zÄÖÜäöüß])(?:(?i:Herr|Herrn|Frau))[ \t]+(?:(?i:Dr\.)[ \t]+)?([A-ZÄÖÜ][A-Za-zÄÖÜäöüß'’\-]+[ \t]+[A-ZÄÖÜ][A-Za-zÄÖÜäöüß'’\-]+(?:[ \t]+[A-ZÄÖÜ][A-Za-zÄÖÜäöüß'’\-]+)?)(?=$|[ \t,.;:!?\r\n])"#
    )

    private static let projectNameRegex = makeRegex(
        #"(?<![A-Za-zÄÖÜäöüß0-9_])(?:(?i:Projekt|Project))[ \t]+[A-ZÄÖÜ][A-Za-zÄÖÜäöüß'’\-]*(?:[ \t]+[A-ZÄÖÜ][A-Za-zÄÖÜäöüß'’\-]*){0,2}(?![A-Za-zÄÖÜäöüß0-9_])"#
    )

    private static let legalFormRegex = makeRegex(
        #"(?i)(?:GmbH[ \t]*&[ \t]*Co\.[ \t]*KG|UG[ \t]*\(haftungsbeschränkt\)|e\.[ \t]*V\.|GmbH|AG|UG|KG|OHG|GbR|SE)[ \t]*$"#
    )

    private static let flowingLegalOrganizationRegex = makeRegex(
        #"(?<![A-Za-zÄÖÜäöüß0-9&.'’\-])(?:(?:[A-ZÄÖÜ][A-Za-zÄÖÜäöüß0-9'’\-]*|&|Co\.)[ \t]+){1,7}(?:(?i:GmbH[ \t]*&[ \t]*Co\.[ \t]*KG|UG[ \t]*\(haftungsbeschränkt\)|e\.[ \t]*V\.|GmbH|AG|UG|KG|OHG|GbR|SE))(?![A-Za-zÄÖÜäöüß0-9])"#
    )

    private static let streetLineRegex = makeRegex(
        #"(?i)\b[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß.'’\-]*(?:straße|str\.|weg|allee|platz|gasse|ring|ufer|damm|chaussee)[ \t]+\d{1,4}[A-Za-z]?\b"#
    )

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid entity detector pattern")
        }
    }
}
