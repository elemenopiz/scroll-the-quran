import Foundation

/// How much room a verse needs on a reader page. Drives the type ramp in `FeatureReader`.
public enum VerseSizeTier: String, Sendable, CaseIterable, Codable {
    /// 40 words or fewer — set large, one screen, lots of air.
    case large
    /// 41–90 words — the middle setting.
    case medium
    /// More than 90 words — the smallest setting, and usually paginated.
    case small

    public init(wordCount: Int) {
        switch wordCount {
        case ...40: self = .large
        case ...90: self = .medium
        default: self = .small
        }
    }

    public init(text: String) {
        self.init(wordCount: VersePaginator.wordCount(text))
    }
}

/// Splits an ayah that is too long for one screen into continuation pages.
///
/// Pages break at sentence boundaries (`". "`, `"; "`, `"? "`, `"! "`), never mid-sentence, so a
/// continuation always starts on a new thought. A sentence longer than `maxWords` on its own is
/// broken at clause boundaries (`", "`) and, only if that is still not enough, on the word.
/// Every page is at most `maxWords` words.
public enum VersePaginator {
    public static let defaultMaxWords = 110

    /// The pages of `text`. Always at least one page; short verses return `[text]` unchanged.
    public static func pages(text: String, maxWords: Int = defaultMaxWords) -> [String] {
        let tidy = normalized(text)
        guard !tidy.isEmpty else { return [] }
        guard maxWords > 0 else { return [tidy] }
        guard wordCount(tidy) > maxWords else { return [tidy] }

        var pages: [String] = []
        var page: [String] = []
        var pageWords = 0

        func flush() {
            guard !page.isEmpty else { return }
            pages.append(page.joined(separator: " "))
            page = []
            pageWords = 0
        }

        for sentence in sentences(in: tidy) {
            let words = wordCount(sentence)
            if words > maxWords {
                flush()
                pages.append(contentsOf: split(oversized: sentence, maxWords: maxWords))
                continue
            }
            if pageWords + words > maxWords {
                flush()
            }
            page.append(sentence)
            pageWords += words
        }
        flush()
        return pages.isEmpty ? [tidy] : pages
    }

    /// `"(2/3)"` for the continuation caption, or nil when there is only one page.
    public static func caption(page: Int, of total: Int) -> String? {
        total > 1 ? "(\(page)/\(total))" : nil
    }

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// Runs of whitespace collapsed to one space, ends trimmed. The words themselves are untouched.
    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Sentences, each keeping its terminating punctuation.
    static func sentences(in text: String) -> [String] {
        let terminators: Set<Character> = [".", ";", "?", "!"]
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)
        var offset = 0
        while offset < characters.count {
            let character = characters[offset]
            current.append(character)
            // A boundary is a terminator followed by a space: "etc. And" splits, "3.5" does not.
            if terminators.contains(character), offset + 1 < characters.count, characters[offset + 1] == " " {
                // Keep closing quotes and brackets with the sentence they end.
                var lookahead = offset + 1
                while lookahead < characters.count, characters[lookahead] == " " {
                    lookahead += 1
                }
                sentences.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                offset = lookahead
                continue
            }
            offset += 1
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty {
            sentences.append(tail)
        }
        return sentences.isEmpty ? [text] : sentences
    }

    /// A single sentence that will not fit: break it at commas, then on the word.
    static func split(oversized sentence: String, maxWords: Int) -> [String] {
        var chunks: [String] = []
        var current: [String] = []
        var currentWords = 0

        func flush() {
            guard !current.isEmpty else { return }
            chunks.append(current.joined(separator: " "))
            current = []
            currentWords = 0
        }

        for clause in clauses(in: sentence) {
            let words = wordCount(clause)
            if words > maxWords {
                flush()
                chunks.append(contentsOf: splitOnWords(clause, maxWords: maxWords))
                continue
            }
            if currentWords + words > maxWords {
                flush()
            }
            current.append(clause)
            currentWords += words
        }
        flush()
        return chunks
    }

    /// Comma-delimited clauses, each keeping its comma.
    static func clauses(in sentence: String) -> [String] {
        var clauses: [String] = []
        var current = ""
        var offset = 0
        let characters = Array(sentence)
        while offset < characters.count {
            let character = characters[offset]
            current.append(character)
            if character == ",", offset + 1 < characters.count, characters[offset + 1] == " " {
                clauses.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                offset += 2
                continue
            }
            offset += 1
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty {
            clauses.append(tail)
        }
        return clauses
    }

    static func splitOnWords(_ text: String, maxWords: Int) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard maxWords > 0 else { return [text] }
        return stride(from: 0, to: words.count, by: maxWords).map { start in
            words[start ..< min(start + maxWords, words.count)].joined(separator: " ")
        }
    }
}
