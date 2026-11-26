import Foundation
import Darwin

struct PatternDetector {
    func detect(in text: String) -> [DetectedMatch] {
        guard !text.isEmpty else {
            return []
        }

        return detectURLs(in: text)
            + detectEmails(in: text)
            + detectCredentials(in: text)
            + detectIBANs(in: text)
            + detectAddresses(in: text)
            + detectUUIDs(in: text)
            + detectMACAddresses(in: text)
            + detectIPs(in: text)
            + detectPhoneNumbers(in: text)
            + detectDomains(in: text)
    }

    private func detectURLs(in text: String) -> [DetectedMatch] {
        matches(for: Self.urlRegex, in: text).compactMap { result in
            guard let resultRange = Range(result.range, in: text) else {
                return nil
            }

            let range = trimmingURLPunctuation(from: resultRange, in: text)
            return makeMatch(in: text, range: range, category: .url)
        }
    }

    private func detectEmails(in text: String) -> [DetectedMatch] {
        matches(for: Self.emailRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .email)
        }
    }

    private func detectIBANs(in text: String) -> [DetectedMatch] {
        matches(for: Self.ibanRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text),
                  let match = makeMatch(in: text, range: range, category: .iban),
                  (15...34).contains(match.normalizedValue.count) else {
                return nil
            }

            return match
        }
    }

    private func detectAddresses(in text: String) -> [DetectedMatch] {
        matches(for: Self.addressRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            return makeMatch(
                in: text,
                range: range,
                category: .address,
                source: .addressRule
            )
        }
    }

    private func detectIPs(in text: String) -> [DetectedMatch] {
        let ipv4Matches = matches(for: Self.ipv4Regex, in: text).compactMap { result -> DetectedMatch? in
            guard let range = Range(result.range, in: text),
                  isValidIPv4(String(text[range])),
                  hasValidIPv4Suffix(after: range.upperBound, in: text) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .ip)
        }

        let ipv6Matches = matches(for: Self.ipv6CandidateRegex, in: text).compactMap { result -> DetectedMatch? in
            guard let resultRange = Range(result.range, in: text) else {
                return nil
            }

            let range = trimmingIPv6Punctuation(from: resultRange, in: text)
            guard isValidIPv6(String(text[range])) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .ip)
        }

        return ipv4Matches + ipv6Matches
    }

    private func detectPhoneNumbers(in text: String) -> [DetectedMatch] {
        matches(for: Self.phoneRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text),
                  isValidPhoneNumber(String(text[range])) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .phone)
        }
    }

    private func detectMACAddresses(in text: String) -> [DetectedMatch] {
        matches(for: Self.macAddressRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .mac)
        }
    }

    private func detectUUIDs(in text: String) -> [DetectedMatch] {
        matches(for: Self.uuidRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .uuid)
        }
    }

    private func detectDomains(in text: String) -> [DetectedMatch] {
        matches(for: Self.domainRegex, in: text).compactMap { result in
            guard let range = Range(result.range, in: text) else {
                return nil
            }

            return makeMatch(in: text, range: range, category: .domain)
        }
    }

    private func detectCredentials(in text: String) -> [DetectedMatch] {
        var matches: [DetectedMatch] = []
        matches += credentialMatches(
            for: Self.secretAssignmentRegex,
            category: .secret,
            in: text
        )
        matches += credentialMatches(
            for: Self.usingPasswordRegex,
            category: .secret,
            in: text
        )
        matches += credentialMatches(
            for: Self.tokenAssignmentRegex,
            category: .token,
            in: text
        )
        matches += credentialMatches(
            for: Self.authorizationHeaderRegex,
            category: .token,
            in: text,
            valueGroups: [1]
        )
        return matches
    }

    private func credentialMatches(
        for regex: NSRegularExpression,
        category: ReplacementCategory,
        in text: String,
        valueGroups: [Int] = [1, 2, 3]
    ) -> [DetectedMatch] {
        matches(for: regex, in: text).compactMap { result in
            for group in valueGroups {
                let valueRange = result.range(at: group)
                guard valueRange.location != NSNotFound,
                      let range = Range(valueRange, in: text),
                      !range.isEmpty else {
                    continue
                }

                return makeMatch(in: text, range: range, category: category)
            }

            return nil
        }
    }

    private func matches(
        for regex: NSRegularExpression,
        in text: String
    ) -> [NSTextCheckingResult] {
        regex.matches(
            in: text,
            range: NSRange(location: 0, length: text.utf16.count)
        )
    }

    private func makeMatch(
        in text: String,
        range: Range<String.Index>,
        category: ReplacementCategory,
        source: DetectionSource = .structured
    ) -> DetectedMatch? {
        guard !range.isEmpty else {
            return nil
        }

        let originalValue = String(text[range])
        return DetectedMatch(
            originalValue: originalValue,
            category: category,
            sourceRange: range,
            normalizedValue: normalizedValue(originalValue, for: category),
            source: source
        )
    }

    private func normalizedValue(
        _ value: String,
        for category: ReplacementCategory
    ) -> String {
        switch category {
        case .email, .domain, .ip:
            value.lowercased()
        case .iban:
            value
                .filter { !$0.isWhitespace }
                .uppercased()
        case .phone:
            value.filter { $0.isNumber || $0 == "+" }
        case .mac:
            value
                .filter { $0.isHexDigit }
                .uppercased()
        case .uuid:
            value.lowercased()
        case .address:
            value
                .lowercased()
                .replacingOccurrences(of: ",", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
        case .url, .secret, .token, .person, .organization, .location, .custom:
            value
        }
    }

    private func trimmingURLPunctuation(
        from range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index> {
        var end = range.upperBound
        let punctuation: Set<Character> = [".", ",", ";", "!", "?", ")", "]", "}", "'", "\""]

        while end > range.lowerBound {
            let previous = text.index(before: end)
            guard punctuation.contains(text[previous]) else {
                break
            }
            end = previous
        }

        return range.lowerBound..<end
    }

    private func trimmingIPv6Punctuation(
        from range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index> {
        var end = range.upperBound

        while end > range.lowerBound {
            let previous = text.index(before: end)
            guard text[previous] == "." else {
                break
            }
            end = previous
        }

        return range.lowerBound..<end
    }

    private func hasValidIPv4Suffix(
        after index: String.Index,
        in text: String
    ) -> Bool {
        guard index < text.endIndex, text[index] == "." else {
            return true
        }

        let next = text.index(after: index)
        guard next < text.endIndex else {
            return true
        }

        // A following digit means this was only a prefix of a longer dotted value.
        // A following letter means the value is part of a domain-like token.
        return !text[next].isNumber && !text[next].isLetter
    }

    private func isValidIPv4(_ value: String) -> Bool {
        let octets = value.split(separator: ".", omittingEmptySubsequences: false)
        return octets.count == 4 && octets.allSatisfy { octet in
            guard let number = Int(octet), octet.count <= 3 else {
                return false
            }
            return (0...255).contains(number)
        }
    }

    private func isValidIPv6(_ value: String) -> Bool {
        var address = in6_addr()
        return value.withCString { pointer in
            inet_pton(AF_INET6, pointer, &address) == 1
        }
    }

    private func isValidPhoneNumber(_ value: String) -> Bool {
        let digitCount = value.filter(\.isNumber).count
        guard digitCount >= 7 else {
            return false
        }

        // A separator or explicit international prefix makes a long numeric token
        // more likely to be a phone number than an arbitrary identifier.
        let hasSeparator = value.contains { character in
            " ()/-".contains(character)
        }
        let hasExplicitInternationalPrefix = value.hasPrefix("+") || value.hasPrefix("00")
        return hasSeparator || hasExplicitInternationalPrefix
    }

    private static let urlRegex = makeRegex(
        #"(?i)\bhttps?://[^\s<>\"']+"#
    )

    private static let emailRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9._%+\-])[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)+(?![A-Za-z0-9_%+\-])"#
    )

    private static let ibanRegex = makeRegex(
        #"(?i)\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){11,30}\b"#
    )

    private static let addressRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9ÄÖÜäöüß])(?:[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß.'’\-]*[ \t]+){0,3}[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß.'’\-]*(?:straße|str\.|weg|allee|platz|gasse|ring|ufer|damm|chaussee)[ \t]+\d{1,4}[A-Za-z]?(?:(?:[ \t]*,[ \t]*|[ \t]*\r?\n[ \t]*)\d{5}[ \t]+[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß'’\-]*(?:[ \t]+[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß'’\-]*){0,2})?(?![A-Za-z0-9ÄÖÜäöüß])"#
    )

    private static let ipv4Regex = makeRegex(
        #"(?<![A-Za-z0-9.])(?:\d{1,3}\.){3}\d{1,3}(?![A-Za-z0-9])"#
    )

    // Candidate extraction is deliberately broad; inet_pton performs the validation.
    private static let ipv6CandidateRegex = makeRegex(
        #"(?i)(?<![0-9a-z:.])[0-9a-f:.]*:[0-9a-f:.]*(?![0-9a-z:.])"#
    )

    private static let phoneRegex = makeRegex(
        #"(?<![A-Za-z0-9])(?:\+[1-9]\d{0,2}|00[1-9]\d{0,2}|0\d{2,4})(?:[ \t()/\-]*\d{2,4}){2,4}(?![A-Za-z0-9:-])"#
    )

    private static let macAddressRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9:-])(?:[0-9A-F]{2}(?::[0-9A-F]{2}){5}|[0-9A-F]{2}(?:-[0-9A-F]{2}){5})(?![A-Za-z0-9:-])"#
    )

    private static let uuidRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9])[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}(?![A-Za-z0-9])"#
    )

    private static let domainRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9@._-])(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?![A-Za-z0-9_-])"#
    )

    private static let secretAssignmentRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9_])(?:password|passwd|pwd|db_password|mysql_password|smtp_password|secret|client_secret)[ \t]*(?:=|:)[ \t]*(?:\"([^\"\r\n]*)\"|'([^'\r\n]*)'|([^\s,;]+))"#
    )

    private static let usingPasswordRegex = makeRegex(
        #"(?i)\busing[ \t]+password[ \t]+(?:\"([^\"\r\n]*)\"|'([^'\r\n]*)'|([^\s,;]+))"#
    )

    private static let tokenAssignmentRegex = makeRegex(
        #"(?i)(?<![A-Za-z0-9_])(?:api_key|access_token|auth_token|bearer_token|token)[ \t]*(?:=|:)[ \t]*(?:\"([^\"\r\n]*)\"|'([^'\r\n]*)'|([^\s,;]+))"#
    )

    private static let authorizationHeaderRegex = makeRegex(
        #"(?i)\bAuthorization[ \t]*:[ \t]*Bearer[ \t]+([^\s,;]+)"#
    )

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid detector pattern")
        }
    }
}
