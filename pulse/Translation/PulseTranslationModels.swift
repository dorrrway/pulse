#if DEBUG
import Foundation
import NaturalLanguage
import Translation

nonisolated enum PulseTranslationLanguage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case chineseSimplified = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: String {
        rawValue
    }

    var localeLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }

    static func defaultTarget(for language: PulseLanguage) -> PulseTranslationLanguage {
        switch language {
        case .english:
            .english
        case .chinese:
            .chineseSimplified
        }
    }

    static func automaticTarget(forDetectedSource source: PulseTranslationLanguage) -> PulseTranslationLanguage {
        switch source {
        case .chineseSimplified:
            .english
        case .english, .japanese, .korean, .french, .german, .spanish:
            .chineseSimplified
        }
    }

    static func supportedLanguage(forRecognizedIdentifier identifier: String) -> PulseTranslationLanguage? {
        if identifier.hasPrefix("zh") {
            return .chineseSimplified
        }

        return allCases.first { language in
            identifier == language.rawValue || identifier.hasPrefix(language.rawValue + "-")
        }
    }
}

nonisolated struct PulseTranslationLanguageDetection: Equatable, Sendable {
    var language: PulseTranslationLanguage
    var confidence: Double
}

nonisolated struct PulseTranslationRequest: Equatable, Sendable {
    var id = UUID()
    var sourceText: String
    var sourceLanguage: PulseTranslationLanguage?
    var targetLanguage: PulseTranslationLanguage
}

nonisolated struct PulseTranslationOutput: Equatable, Sendable {
    var sourceText: String
    var targetText: String
    var sourceLanguageIdentifier: String
    var targetLanguageIdentifier: String
}

nonisolated enum PulseTranslationService {
    static func detectedSourceLanguage(for text: String) -> PulseTranslationLanguageDetection? {
        if let scriptLanguage = scriptDetectedSourceLanguage(for: text) {
            return PulseTranslationLanguageDetection(language: scriptLanguage, confidence: 1)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)

        let supportedHypotheses = hypotheses.compactMap { language, confidence -> PulseTranslationLanguageDetection? in
            guard let supportedLanguage = PulseTranslationLanguage.supportedLanguage(
                forRecognizedIdentifier: language.rawValue
            ) else {
                return nil
            }

            return PulseTranslationLanguageDetection(
                language: supportedLanguage,
                confidence: confidence
            )
        }

        if let strongestSupportedHypothesis = supportedHypotheses.max(by: { $0.confidence < $1.confidence }) {
            return strongestSupportedHypothesis
        }

        guard
            let dominantLanguage = recognizer.dominantLanguage,
            let supportedLanguage = PulseTranslationLanguage.supportedLanguage(
                forRecognizedIdentifier: dominantLanguage.rawValue
            )
        else {
            return nil
        }

        return PulseTranslationLanguageDetection(language: supportedLanguage, confidence: 0)
    }

    static func availabilityStatus(for request: PulseTranslationRequest) async throws -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        if let sourceLanguage = request.sourceLanguage {
            return await availability.status(
                from: sourceLanguage.localeLanguage,
                to: request.targetLanguage.localeLanguage
            )
        }

        return try await availability.status(
            for: request.sourceText,
            to: request.targetLanguage.localeLanguage
        )
    }

    static func translate(
        _ request: PulseTranslationRequest,
        using session: sending TranslationSession
    ) async throws -> PulseTranslationOutput {
        // Automatic source-language sessions need the actual source text for language detection.
        if request.sourceLanguage != nil {
            try await session.prepareTranslation()
        }
        let response = try await session.translate(request.sourceText)
        return PulseTranslationOutput(
            sourceText: response.sourceText,
            targetText: response.targetText,
            sourceLanguageIdentifier: response.sourceLanguage.minimalIdentifier,
            targetLanguageIdentifier: response.targetLanguage.minimalIdentifier
        )
    }

    private static func scriptDetectedSourceLanguage(for text: String) -> PulseTranslationLanguage? {
        var containsHan = false

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x309F, 0x30A0...0x30FF:
                return .japanese
            case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F:
                return .korean
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                containsHan = true
            default:
                continue
            }
        }

        return containsHan ? .chineseSimplified : nil
    }
}
#endif
