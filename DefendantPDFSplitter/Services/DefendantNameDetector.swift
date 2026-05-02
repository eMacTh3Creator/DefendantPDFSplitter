import Foundation

struct DefendantNameDetector {

    /// Attempt to detect a defendant/respondent name from page text.
    /// Uses multiple heuristics based on common court document patterns.
    static func detectName(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Strategy 1: Look for "Defendant/Respondent: Name" inline (handles both
        // right-of-label and left-of-label multi-column layouts)
        if let name = extractFromInlineLabel(lines: lines) {
            return name
        }

        // Strategy 2: Look for name after "vs." or "v." in court caption
        if let name = extractFromVsPattern(lines: lines) {
            return name
        }

        // Strategy 3: Look for name near "Defendant" or "Respondent" keywords
        // (line above/below — used for multi-line layouts)
        if let name = extractNearDefendantKeyword(lines: lines) {
            return name
        }

        return nil
    }

    /// Pennsylvania Municipal Court / similar layouts put each field as
    /// "Label: Value" — but multi-column scans get OCR'd left-to-right into a
    /// single line, so we need to look BOTH for "Defendant/Respondent: Name"
    /// (right-of-label) AND "Name ... Defendant/Respondent ..." (left-of-label,
    /// where the name is in a left column and the label is in a middle column).
    private static func extractFromInlineLabel(lines: [String]) -> String? {
        // Detector for the literal Defendant/Respondent (or Respondent/Defendant) label.
        // Treats slashes, colons, dashes, and OCR'd "DefendantRespondent" (no slash) the same.
        let labelRegex = try? NSRegularExpression(
            pattern: "(?i)\\b(defendant\\s*/?\\s*respondent|respondent\\s*/?\\s*defendant)\\b"
        )
        guard let labelRegex else { return nil }

        // Lines containing the document-type list we want to ignore.
        let docTypeKeywords = [
            "summons", "complaint", "verification", "exhibits",
            "affidavit", "statement of claim", "non-service", "of service"
        ]

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = labelRegex.firstMatch(in: line, range: range) else { continue }

            let labelStart = match.range.location
            let labelEnd = match.range.location + match.range.length

            // Try AFTER the label: "Defendant/Respondent: Name"
            if labelEnd < nsLine.length {
                let after = nsLine.substring(from: labelEnd)
                if let name = pickFirstNameSegment(from: after, docTypeKeywords: docTypeKeywords) {
                    return name
                }
            }

            // Try BEFORE the label: "Name   Defendant/Respondent  ..."
            if labelStart > 0 {
                let before = nsLine.substring(with: NSRange(location: 0, length: labelStart))
                if let name = pickLastNameSegment(from: before, docTypeKeywords: docTypeKeywords) {
                    return name
                }
            }
        }
        return nil
    }

    /// Pick the first plausible name from the start of `text` (used for after-label).
    /// Stops at the first occurrence of another label or document-type keyword.
    private static func pickFirstNameSegment(from text: String, docTypeKeywords: [String]) -> String? {
        let trimmed = text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-")))

        // Cut at any other label keyword we recognize
        let cutMarkers = ["plaintiff", "petitioner", "case no", "case number", "hearing", "address"]
            + docTypeKeywords

        var slice = trimmed
        let lower = slice.lowercased()
        for marker in cutMarkers {
            if let r = lower.range(of: marker) {
                let cutAt = lower.distance(from: lower.startIndex, to: r.lowerBound)
                let idx = slice.index(slice.startIndex, offsetBy: cutAt)
                slice = String(slice[..<idx])
                break
            }
        }

        slice = slice.trimmingCharacters(in: .whitespacesAndNewlines)

        // Reject if the slice itself is a doc-type list
        let sliceLower = slice.lowercased()
        if docTypeKeywords.contains(where: { sliceLower.hasPrefix($0) }) { return nil }

        return isPlausibleName(slice) ? cleanName(slice) : nil
    }

    /// Pick the last plausible name from the end of `text` (used for before-label).
    /// In the multi-column layout, the defendant name is at the left edge of the
    /// line, but if there's other text on that line, we want the rightmost name-like chunk.
    private static func pickLastNameSegment(from text: String, docTypeKeywords: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Drop everything before known left-column labels
        let leftCutMarkers = ["plaintiff/petitioner", "petitioner", "plaintiff", "case no"]
        var slice = trimmed
        let lower = slice.lowercased()
        for marker in leftCutMarkers {
            if let r = lower.range(of: marker) {
                let cutAt = lower.distance(from: lower.startIndex, to: r.upperBound)
                let idx = slice.index(slice.startIndex, offsetBy: cutAt)
                slice = String(slice[idx...])
                break
            }
        }

        slice = slice
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-,")))

        // The remaining text is something like "Tonya Mitchell" or "JPMorgan Chase Bank N.A.   Tonya Mitchell".
        // Take the last 2–4 words (typical name length); if it still looks plausible, use it.
        let words = slice.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return nil }

        // Try several tail lengths — names are usually 2–4 words
        for n in [4, 3, 2] {
            guard words.count >= n else { continue }
            let candidate = words.suffix(n).joined(separator: " ")
            let candLower = candidate.lowercased()

            // Reject doc-type fragments
            if docTypeKeywords.contains(where: { candLower.contains($0) }) { continue }

            if isPlausibleName(candidate) {
                return cleanName(candidate)
            }
        }

        // Fallback: try the whole slice
        return isPlausibleName(slice) ? cleanName(slice) : nil
    }

    // MARK: - Detection strategies

    /// Look for patterns like "JOHN DOE, Defendant/Respondent"
    /// or "Defendant/Respondent: JOHN DOE"
    private static func extractFromDefendantLabel(lines: [String]) -> String? {
        let labelPatterns = [
            "defendant/respondent",
            "respondent/defendant",
            "defendant",
            "respondent"
        ]

        for line in lines {
            let lower = line.lowercased()
            for pattern in labelPatterns {
                if lower.contains(pattern) {
                    // Try "Name, Defendant" format
                    if let commaIndex = lower.range(of: pattern)?.lowerBound {
                        let before = String(line[line.startIndex..<commaIndex])
                            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
                        if isPlausibleName(before) {
                            return cleanName(before)
                        }
                    }

                    // Try "Defendant: Name" or "Defendant - Name" format
                    if let colonIndex = lower.range(of: pattern)?.upperBound {
                        let after = String(line[colonIndex...])
                            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":,-")))
                        if isPlausibleName(after) {
                            return cleanName(after)
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Look for "vs." or "v." pattern and take the name on the line(s) below it
    private static func extractFromVsPattern(lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)

            let isVsLine = lower == "vs." || lower == "v." ||
                lower == "vs" || lower == "v" ||
                lower.hasSuffix(" vs.") || lower.hasSuffix(" v.")

            if isVsLine {
                // Take the next non-empty line as the defendant name
                for nextIndex in (index + 1)..<min(index + 4, lines.count) {
                    let candidate = lines[nextIndex]
                        .trimmingCharacters(in: .whitespaces)
                    let cleaned = candidate
                        .replacingOccurrences(of: ",", with: "")
                        .trimmingCharacters(in: .whitespaces)

                    // Skip lines that are just labels
                    let candidateLower = cleaned.lowercased()
                    if candidateLower.contains("defendant") || candidateLower.contains("respondent") {
                        continue
                    }
                    if candidateLower.isEmpty || candidateLower.count < 2 {
                        continue
                    }

                    if isPlausibleName(cleaned) {
                        return cleanName(cleaned)
                    }
                }
            }
        }
        return nil
    }

    /// Look for lines near "Defendant" or "Respondent" keywords
    private static func extractNearDefendantKeyword(lines: [String]) -> String? {
        let keywords = ["defendant", "respondent"]

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard keywords.contains(where: { lower.contains($0) }) else { continue }

            // Check the line above
            if index > 0 {
                let candidate = lines[index - 1].trimmingCharacters(in: .whitespaces)
                let lower = candidate.lowercased()
                if !lower.contains("vs") && !lower.contains("plaintiff") && isPlausibleName(candidate) {
                    return cleanName(candidate)
                }
            }

            // Check the line below
            if index + 1 < lines.count {
                let candidate = lines[index + 1].trimmingCharacters(in: .whitespaces)
                let lower = candidate.lowercased()
                if !lower.contains("vs") && !lower.contains("plaintiff") && isPlausibleName(candidate) {
                    return cleanName(candidate)
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    /// Check if a string looks like a plausible person or company name
    private static func isPlausibleName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 100 else { return false }

        let lower = trimmed.lowercased()
        let skipWords = ["court", "county", "state", "case", "docket", "judge",
                         "plaintiff", "honorable", "order", "motion", "filed",
                         "page", "date", "civil", "division", "no.", "number"]
        if skipWords.contains(where: { lower.hasPrefix($0) }) { return false }

        // Must contain at least one letter
        return trimmed.rangeOfCharacter(from: .letters) != nil
    }

    /// Clean up a detected name
    private static func cleanName(_ name: String) -> String {
        var cleaned = name
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.;:()")))

        // Remove trailing "et al" or "et al."
        let suffixes = [" et al.", " et al", " ET AL.", " ET AL"]
        for suffix in suffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}
