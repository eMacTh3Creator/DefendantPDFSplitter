import Foundation

struct DefendantNameDetector {

    /// Attempt to detect a defendant/respondent name from page text.
    /// Uses multiple heuristics based on common court document patterns.
    static func detectName(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Strategy 1: Look for explicit "Defendant/Respondent" label on the same line
        if let name = extractFromDefendantLabel(lines: lines) {
            return name
        }

        // Strategy 2: Look for name after "vs." or "v." in court caption
        if let name = extractFromVsPattern(lines: lines) {
            return name
        }

        // Strategy 3: Look for name near "Defendant" or "Respondent" keywords
        if let name = extractNearDefendantKeyword(lines: lines) {
            return name
        }

        return nil
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
