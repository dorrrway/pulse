#if DEBUG
import AppKit
import SwiftUI
import Translation

struct TranslationPanelView: View {
    @Environment(PulseStore.self) private var store

    @State private var sourceText = ""
    @State private var sourceLanguage: PulseTranslationLanguage?
    @State private var targetLanguage: PulseTranslationLanguage = .chineseSimplified
    @State private var pendingRequest: PulseTranslationRequest?
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var output: PulseTranslationOutput?
    @State private var status: TranslationPanelStatus = .idle
    @State private var didApplyDefaultTargetLanguage = false
    @State private var didCopyOutput = false
    @State private var copyConfirmationGeneration = 0

    private var strings: PulseStrings {
        store.strings
    }

    private var trimmedSourceText: String {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSameLanguagePair: Bool {
        sourceLanguage == targetLanguage
    }

    private var canTranslate: Bool {
        !trimmedSourceText.isEmpty && !status.isWorking && !isSameLanguagePair
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            languageControls

            sourceEditor

            outputPane

            footer
        }
        .padding(.horizontal, PulsePanelLayout.outerPadding)
        .padding(.top, PulsePanelLayout.outerPadding)
        .padding(.bottom, PulsePanelLayout.footerBottomPadding)
        .frame(
            width: PulseIslandLayout.attachedPanelSize.width,
            height: PulseIslandLayout.attachedPanelSize.height,
            alignment: .top
        )
        .onAppear(perform: applyDefaultTargetLanguageIfNeeded)
        .translationTask(translationConfiguration) { session in
            guard let pendingRequest else {
                return
            }

            await translate(pendingRequest, using: session)
        }
    }

    private var languageControls: some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            TranslationSourceLanguagePicker(
                title: strings.text(.translationSourceLanguage),
                automaticTitle: strings.text(.translationAutomaticLanguage),
                selection: $sourceLanguage,
                languageTitle: { strings.translationLanguageName($0) }
            )

            TranslationIconButton(
                systemName: "arrow.left.arrow.right",
                help: strings.text(.translationSwapLanguages),
                isDisabled: sourceLanguage == nil
            ) {
                swapLanguages()
            }

            TranslationTargetLanguagePicker(
                title: strings.text(.translationTargetLanguage),
                selection: $targetLanguage,
                languageTitle: { strings.translationLanguageName($0) }
            )
        }
        .frame(height: TranslationPanelLayout.controlHeight)
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            HStack(alignment: .center, spacing: PulseDesign.Spacing.xs) {
                Text(strings.text(.translationSourceText))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Spacer(minLength: 0)

                TranslationIconButton(
                    systemName: "xmark",
                    help: strings.text(.translationClearText),
                    isDisabled: sourceText.isEmpty
                ) {
                    clearText()
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $sourceText)
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, PulseDesign.Spacing.xs)
                    .padding(.vertical, PulseDesign.Spacing.xs)

                if sourceText.isEmpty {
                    Text(strings.text(.translationInputPlaceholder))
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.34))
                        .padding(.horizontal, PulseDesign.Spacing.md)
                        .padding(.vertical, PulseDesign.Spacing.md)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: TranslationPanelLayout.editorHeight)
            .background(TranslationPanelLayout.fieldFill, in: TranslationPanelLayout.fieldShape)
            .overlay {
                TranslationPanelLayout.fieldShape
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: PulseDesign.Spacing.xs) {
            HStack(alignment: .center, spacing: PulseDesign.Spacing.xs) {
                Text(strings.text(.translationResult))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))

                if let output {
                    Text(strings.translationDetectedLanguage(output.sourceLanguageIdentifier))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                TranslationIconButton(
                    systemName: didCopyOutput ? "checkmark" : "doc.on.doc",
                    help: strings.text(.translationCopyResult),
                    isDisabled: output == nil
                ) {
                    copyOutput()
                }
            }

            ScrollView {
                Text(output?.targetText ?? strings.text(.translationOutputPlaceholder))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(output == nil ? .white.opacity(0.34) : .white.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(PulseDesign.Spacing.sm)
            }
            .frame(maxHeight: .infinity)
            .background(TranslationPanelLayout.fieldFill, in: TranslationPanelLayout.fieldShape)
            .overlay {
                TranslationPanelLayout.fieldShape
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: PulseDesign.Spacing.xs) {
            if let statusText {
                Text(statusText)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(status.isFailure || isSameLanguagePair ? .orange.opacity(0.9) : .white.opacity(0.46))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Button {
                submitTranslation()
            } label: {
                HStack(spacing: PulseDesign.Spacing.fine) {
                    if status.isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.72)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)
                    }

                    Text(strings.text(.translationTranslateAction))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(canTranslate ? .white.opacity(0.96) : .white.opacity(0.38))
                .padding(.horizontal, PulseDesign.Spacing.sm)
                .frame(height: PulseDesign.Control.buttonSide)
                .background {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(canTranslate ? Color.accentColor.opacity(0.9) : .white.opacity(0.08))
                }
            }
            .buttonStyle(.plain)
            .disabled(!canTranslate)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .frame(height: PulsePanelLayout.footerHeight, alignment: .center)
    }

    private var statusText: String? {
        if isSameLanguagePair {
            return strings.text(.translationSameLanguage)
        }

        switch status {
        case .idle:
            return output == nil ? nil : strings.text(.translationReady)
        case .checkingAvailability:
            return strings.text(.translationCheckingAvailability)
        case .preparing:
            return strings.text(.translationPreparing)
        case .translating:
            return strings.text(.translationTranslating)
        case .failed(let message):
            return message
        }
    }

    private func applyDefaultTargetLanguageIfNeeded() {
        guard !didApplyDefaultTargetLanguage else {
            return
        }

        targetLanguage = PulseTranslationLanguage.defaultTarget(for: store.languagePreference.resolvedLanguage)
        didApplyDefaultTargetLanguage = true
    }

    private func submitTranslation() {
        guard canTranslate else {
            return
        }

        let sourceText = trimmedSourceText
        guard let effectiveSourceLanguage = effectiveSourceLanguage(for: sourceText) else {
            pendingRequest = nil
            output = nil
            didCopyOutput = false
            status = .failed(strings.text(.translationUnableToDetectLanguage))
            return
        }

        let effectiveTargetLanguage = effectiveTargetLanguage(for: effectiveSourceLanguage)
        if targetLanguage != effectiveTargetLanguage {
            targetLanguage = effectiveTargetLanguage
        }

        let request = PulseTranslationRequest(
            sourceText: sourceText,
            sourceLanguage: effectiveSourceLanguage,
            targetLanguage: effectiveTargetLanguage
        )
        pendingRequest = request
        output = nil
        didCopyOutput = false
        status = .checkingAvailability

        let nextConfiguration = translationConfiguration(
            source: effectiveSourceLanguage,
            target: effectiveTargetLanguage
        )

        if translationConfiguration == nextConfiguration {
            translationConfiguration?.invalidate()
        } else {
            translationConfiguration = nextConfiguration
        }
    }

    private func effectiveSourceLanguage(for sourceText: String) -> PulseTranslationLanguage? {
        if let sourceLanguage {
            return sourceLanguage
        }

        return PulseTranslationService.detectedSourceLanguage(for: sourceText)?.language
    }

    private func effectiveTargetLanguage(for sourceLanguage: PulseTranslationLanguage) -> PulseTranslationLanguage {
        if self.sourceLanguage == nil && sourceLanguage == targetLanguage {
            return PulseTranslationLanguage.automaticTarget(forDetectedSource: sourceLanguage)
        }

        return targetLanguage
    }

    private func translationConfiguration(
        source: PulseTranslationLanguage,
        target: PulseTranslationLanguage
    ) -> TranslationSession.Configuration {
        if #available(macOS 26.4, *) {
            return TranslationSession.Configuration(
                source: source.localeLanguage,
                target: target.localeLanguage,
                preferredStrategy: .lowLatency
            )
        }

        return TranslationSession.Configuration(
            source: source.localeLanguage,
            target: target.localeLanguage
        )
    }

    private func translate(_ request: PulseTranslationRequest, using session: sending TranslationSession) async {
        do {
            let availabilityStatus = try await PulseTranslationService.availabilityStatus(for: request)
            guard pendingRequest?.id == request.id else {
                return
            }
            guard availabilityStatus != .unsupported else {
                status = .failed(strings.text(.translationUnsupportedLanguagePair))
                return
            }

            status = availabilityStatus == .installed ? .translating : .preparing
            let translatedOutput = try await PulseTranslationService.translate(request, using: session)
            guard pendingRequest?.id == request.id else {
                return
            }

            output = translatedOutput
            status = .idle
        } catch is CancellationError {
            status = .idle
        } catch {
            guard pendingRequest?.id == request.id else {
                return
            }
            status = .failed(strings.translationFailureMessage(error.localizedDescription))
        }
    }

    private func clearText() {
        sourceText = ""
        pendingRequest = nil
        output = nil
        status = .idle
        didCopyOutput = false
    }

    private func swapLanguages() {
        guard let sourceLanguage else {
            return
        }

        self.sourceLanguage = targetLanguage
        targetLanguage = sourceLanguage
        output = nil
        didCopyOutput = false
        if status.isFailure {
            status = .idle
        }
    }

    private func copyOutput() {
        guard let output else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output.targetText, forType: .string)
        didCopyOutput = true
        copyConfirmationGeneration += 1
        let generation = copyConfirmationGeneration

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            guard copyConfirmationGeneration == generation else {
                return
            }

            didCopyOutput = false
        }
    }
}

private enum TranslationPanelStatus: Equatable {
    case idle
    case checkingAvailability
    case preparing
    case translating
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .checkingAvailability, .preparing, .translating:
            true
        case .idle, .failed:
            false
        }
    }

    var isFailure: Bool {
        if case .failed = self {
            return true
        }

        return false
    }
}

private struct TranslationSourceLanguagePicker: View {
    var title: String
    var automaticTitle: String
    @Binding var selection: PulseTranslationLanguage?
    var languageTitle: (PulseTranslationLanguage) -> String

    var body: some View {
        Picker(title, selection: $selection) {
            Text(automaticTitle)
                .tag(Optional<PulseTranslationLanguage>.none)

            ForEach(PulseTranslationLanguage.allCases) { language in
                Text(languageTitle(language))
                    .tag(Optional(language))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(minWidth: 132, maxWidth: .infinity)
    }
}

private struct TranslationTargetLanguagePicker: View {
    var title: String
    @Binding var selection: PulseTranslationLanguage
    var languageTitle: (PulseTranslationLanguage) -> String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(PulseTranslationLanguage.allCases) { language in
                Text(languageTitle(language))
                    .tag(language)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(minWidth: 132, maxWidth: .infinity)
    }
}

private struct TranslationIconButton: View {
    var systemName: String
    var help: String
    var isDisabled = false
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(isDisabled ? 0.24 : 0.62))
                .frame(width: PulseDesign.Control.buttonSide, height: PulseDesign.Control.buttonSide)
                .background {
                    RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous)
                        .fill(.white.opacity(isHovering && !isDisabled ? PulseDesign.Opacity.hoverFillOnDark : 0))
                }
                .contentShape(RoundedRectangle(cornerRadius: PulseDesign.Radius.selectedControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private enum TranslationPanelLayout {
    static let controlHeight: CGFloat = 32
    static let editorHeight: CGFloat = 210
    static let fieldFill = Color.white.opacity(0.07)
    static let fieldShape = RoundedRectangle(cornerRadius: PulseDesign.Radius.card, style: .continuous)
}
#endif
