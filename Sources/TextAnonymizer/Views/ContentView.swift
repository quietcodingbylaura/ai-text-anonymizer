import Foundation
import AppKit
import SwiftUI

struct ContentView: View {
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var enabledCategories = ReplacementCategory.allCategories
    @State private var detectedItems: [DetectedItem] = []
    @State private var inputHighlights: [DetectionHighlight] = []
    @State private var manualDetections: [ManualDetection] = []
    @State private var analyzedMatches: [DetectedMatch] = []
    @State private var selectedDetectionIDs: Set<DetectionID> = []
    @State private var selectedInputRange: NSRange?
    @State private var useLocalAIDetection = false
    @State private var localAIAvailability: LocalAIAvailability = .unsupportedOS
    @State private var analysisState: AnalysisState = .idle
    @State private var localAIUnavailableAfterAnalysis = false
    @State private var isSettingsPresented = false
    @State private var isHelpPresented = false
    @State private var isDetectedItemsExpanded = true
    @State private var restorationResult: RestorationResult?
    @State private var anonymizationSession: AnonymizationSession?
    @State private var anonymizedCopyFeedbackVisible = false
    @State private var restoredCopyFeedbackVisible = false
    @State private var anonymizedCopyFeedbackGeneration = 0
    @State private var restoredCopyFeedbackGeneration = 0

    private let anonymizer = Anonymizer()
    private let restorer = Restorer()
    private let localAIDetector = LocalAIDetector()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    appHeader

                    mainWorkspace(
                        isWide: geometry.size.width >= AppTheme.wideLayoutBreakpoint
                    )

                    detectedItemsCard

                }
                .padding(AppTheme.pagePadding)
                .frame(maxWidth: 1320, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(
            minWidth: AppTheme.minimumWindowWidth,
            minHeight: AppTheme.minimumWindowHeight
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(
                enabledCategories: $enabledCategories,
                useLocalAIDetection: $useLocalAIDetection,
                localAIAvailability: localAIAvailability,
                onCategoryChange: refreshPreview,
                onLocalAIChange: setLocalAIEnabled,
                onOpenSystemSettings: openSystemSettings
            )
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpView()
        }
        .onAppear {
            localAIAvailability = localAIDetector.availability
        }
        .onChange(of: inputText) { _ in
            // Manual ranges belong to one exact source revision. Discard them
            // after edits instead of risking application to the wrong text.
            manualDetections = []
            analyzedMatches = []
            detectedItems = []
            inputHighlights = []
            selectedDetectionIDs = []
            selectedInputRange = nil
            localAIUnavailableAfterAnalysis = false
            analysisState = inputText.isEmpty ? .idle : .stale
        }
        .onChange(of: outputText) { _ in
            // A changed external text no longer represents the previous
            // restoration result, but it does not invalidate the mapping.
            restorationResult = nil
        }
    }

    private var appHeader: some View {
        HStack(alignment: .top, spacing: AppTheme.standardSpacing) {
            VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
                Text("AI Text Anon")
                    .font(.title2.weight(.semibold))

                Text("Anonymize sensitive text before sharing it with AI.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isHelpPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .help("Help")
            .accessibilityLabel("Help")

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .help("Anonymization Settings")
            .accessibilityLabel("Anonymization Settings")
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func mainWorkspace(isWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            if isWide {
                HStack(alignment: .top, spacing: AppTheme.sectionSpacing) {
                    originalEditorCard
                    anonymizedEditorCard
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    originalEditorCard
                    anonymizedEditorCard
                }
            }

            directionActionRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var originalEditorCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
                originalTextSection
                originalEditorActions
                manualMarkingHint
            }
        }
    }

    private var anonymizedEditorCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
                anonymizedTextSection
                anonymizedEditorActions

                Text("When using this text with an AI, keep placeholders such as [PERSON_1] unchanged.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                restoreSessionControls

                if let restorationResult {
                    restorationSummary(for: restorationResult)
                }
            }
        }
    }

    private var directionActionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppTheme.standardSpacing) {
                anonymizeButton
                restoreButton
            }
            VStack(spacing: AppTheme.controlSpacing) {
                anonymizeButton
                restoreButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var anonymizeButton: some View {
        Button {
            anonymizeInput()
        } label: {
            Label("Anonymize", systemImage: "arrow.right")
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(PrimaryButtonStyle())
        .disabled(inputText.isEmpty || analysisState != .complete)
    }

    private var restoreButton: some View {
        Button {
            restoreEditedTextFromRight()
        } label: {
            Label("Restore", systemImage: "arrow.left")
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(anonymizationSession == nil || outputText.isEmpty)
    }

    private var restoreSessionControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.controlSpacing) {
            if let anonymizationSession, !anonymizationSession.isEmpty {
                Text("Restore data available for this session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("Clear Restore Data", role: .destructive) {
                        clearRestoreData()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.medium)
                }
                .menuStyle(.borderlessButton)
                .help("Clear Restore Data")
                .accessibilityLabel("Clear Restore Data")
            } else {
                Text("No restore data available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func restorationSummary(for result: RestorationResult) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            if !result.restoredPlaceholders.isEmpty {
                Text("Restored: \(result.restoredPlaceholders.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !result.unresolvedPlaceholders.isEmpty {
                Text("Could not restore: \(result.unresolvedPlaceholders.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if !result.missingPlaceholders.isEmpty {
                Text("Known placeholders not present: \(result.missingPlaceholders.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var anonymizedTextSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            editorSectionHeader(
                title: "Anonymized / External Text",
                subtitle: "Anonymized text for external editing",
                copyLabel: "Copy Anonymized Text",
                feedbackVisible: anonymizedCopyFeedbackVisible,
                isCopyDisabled: outputText.isEmpty,
                copyAction: copyAnonymizedText
            )

            TextEditor(text: $outputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(AppTheme.compactSpacing)
                .background(
                    AppTheme.editorBackground,
                    in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
                        .stroke(AppTheme.cardBorder)
                }
                .frame(
                    minHeight: AppTheme.editorMinHeight,
                    idealHeight: AppTheme.editorIdealHeight,
                    maxHeight: AppTheme.editorMaxHeight
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func editorSectionHeader(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        copyLabel: LocalizedStringKey,
        feedbackVisible: Bool,
        isCopyDisabled: Bool,
        copyAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: AppTheme.controlSpacing) {
            AppSectionHeader(title, subtitle: subtitle)

            Spacer(minLength: AppTheme.compactSpacing)

            if feedbackVisible {
                Label("Copied to clipboard", systemImage: "checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: copyAction) {
                Image(systemName: "doc.on.doc")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .help(copyLabel)
            .accessibilityLabel(copyLabel)
            .disabled(isCopyDisabled)
        }
    }

    private var originalTextSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            editorSectionHeader(
                title: "Internal Text",
                subtitle: "Original or restored text containing real data",
                copyLabel: "Copy Internal Text",
                feedbackVisible: restoredCopyFeedbackVisible,
                isCopyDisabled: inputText.isEmpty,
                copyAction: copyInternalText
            )

            SelectableTextEditor(
                text: $inputText,
                highlights: $inputHighlights,
                onSelectionChange: { range in
                    selectedInputRange = range
                },
                onMarkSelection: { category, range in
                    markSelectedText(as: category, in: range)
                }
            )
            .padding(AppTheme.compactSpacing)
            .background(
                AppTheme.editorBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
                    .stroke(AppTheme.cardBorder)
            }
            .frame(
                minHeight: AppTheme.editorMinHeight,
                idealHeight: AppTheme.editorIdealHeight,
                maxHeight: AppTheme.editorMaxHeight
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var originalEditorActions: some View {
        HStack(spacing: AppTheme.controlSpacing) {
            Button("Clear") {
                clearOriginalText()
            }
            .buttonStyle(SecondaryButtonStyle(compact: true))
            .disabled(inputText.isEmpty)

            Button("Analyze Text") {
                analyzeText()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(inputText.isEmpty || analysisState == .analyzing)

            if analysisState == .analyzing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Analyzing text")
            }

            Text(analysisStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var anonymizedEditorActions: some View {
        HStack(spacing: AppTheme.controlSpacing) {
            Button("Clear") {
                clearExternalText()
            }
            .buttonStyle(SecondaryButtonStyle(compact: true))
            .disabled(outputText.isEmpty)

            Spacer()
        }
    }

    private var detectedItemsCard: some View {
        AppCard {
            DisclosureGroup(isExpanded: $isDetectedItemsExpanded) {
                detectedItemsSection
            } label: {
                AppSectionHeader(
                    detectedItemsTitle,
                    subtitle: Text("Review and select individual detections.")
                )
            }
        }
    }

    private var detectedItemsTitle: Text {
        detectedItems.isEmpty
            ? Text("Detected Items")
            : Text("Detected Items (\(detectedItems.count))")
    }

    private var analysisStatusText: LocalizedStringKey {
        switch analysisState {
        case .idle:
            "Ready to analyze"
        case .analyzing:
            "Analyzing…"
        case .complete:
            localAIUnavailableAfterAnalysis
                ? "Analysis complete · Local AI unavailable"
                : "Analysis complete"
        case .stale:
            "Text changed · Analyze again"
        case .unavailable(let message), .failed(let message):
            LocalizedStringKey(message)
        }
    }

    private var detectedItemsEmptyMessage: LocalizedStringKey {
        analysisState == .complete
            ? "No supported sensitive items detected."
            : "Analyze Text to detect supported sensitive items."
    }

    private var manualMarkingHint: some View {
        Text("Select undetected sensitive content and add it with a right-click.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var detectedItemsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            HStack(spacing: AppTheme.controlSpacing) {
                Button("Select All Items") {
                    selectedDetectionIDs = Set(detectedItems.map(\.id))
                    refreshPreview()
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))

                Button("Select None Items") {
                    selectedDetectionIDs = []
                    refreshPreview()
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
            }

            if detectedItems.isEmpty {
                Text(detectedItemsEmptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.standardSpacing)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
                        ForEach(detectedItems) { item in
                            detectedItemRow(item)
                        }
                    }
                    .padding(AppTheme.standardSpacing)
                }
                .frame(minHeight: 80, maxHeight: 230)
                .background(
                    AppTheme.editorBackground,
                    in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
                        .stroke(AppTheme.cardBorder)
                }
            }
        }
    }

    private func detectedItemRow(_ item: DetectedItem) -> some View {
        HStack(alignment: .top, spacing: AppTheme.controlSpacing) {
            Toggle(
                "",
                isOn: detectionBinding(for: item)
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(!enabledCategories.contains(item.category))
            .accessibilityLabel("\(item.category.localizedDisplayName): \(item.originalValue)")
            .accessibilityValue(
                item.isAnonymized
                    ? String(localized: "Anonymized")
                    : String(localized: "Not anonymized")
            )

            VStack(alignment: .leading, spacing: AppTheme.compactSpacing / 2) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.controlSpacing) {
                    Text(item.category.localizedDisplayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: AppTheme.compactSpacing)

                    if let replacementValue = item.replacementValue {
                        Text("→ \(replacementValue)")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not anonymized")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.source.localizedDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if item.source == .manual {
                        Button {
                            removeManualDetection(item)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Remove manual detection")
                        .accessibilityLabel("Remove manual detection")
                    }
                }

                Text(item.originalValue)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.isAnonymized ? 1 : 0.65)
    }

    private func detectionBinding(for item: DetectedItem) -> Binding<Bool> {
        Binding(
            get: {
                enabledCategories.contains(item.category)
                    && selectedDetectionIDs.contains(item.id)
            },
            set: { isSelected in
                if isSelected {
                    selectedDetectionIDs.insert(item.id)
                } else {
                    selectedDetectionIDs.remove(item.id)
                }
                refreshPreview()
            }
        )
    }

    private func markSelectedText(as category: ReplacementCategory, in range: NSRange) {
        guard let manualDetection = ManualDetection(
                  text: inputText,
                  sourceRange: range,
                  category: category
              ) else {
            return
        }

        let overlappingIDs = manualDetections
            .filter { rangesOverlap($0.sourceRange, range) }
            .map(\.id)
        manualDetections.removeAll {
            rangesOverlap($0.sourceRange, range)
        }
        selectedDetectionIDs.subtract(overlappingIDs)
        manualDetections.append(manualDetection)
        selectedDetectionIDs.insert(manualDetection.id)
        self.selectedInputRange = nil
        refreshPreview()
    }

    private func removeManualDetection(_ item: DetectedItem) {
        manualDetections.removeAll { $0.id == item.id }
        selectedDetectionIDs.remove(item.id)

        // If the manual item had replaced an automatic match at the same range,
        // selecting its ID again lets that automatic match resume normally.
        selectedDetectionIDs.insert(item.id)
        refreshPreview()
    }

    private func rangesOverlap(_ first: NSRange, _ second: NSRange) -> Bool {
        let firstEnd = first.location + first.length
        let secondEnd = second.location + second.length
        return first.location < secondEnd && second.location < firstEnd
    }

    private func clearOriginalText() {
        inputText = ""
        detectedItems = []
        inputHighlights = []
        manualDetections = []
        analyzedMatches = []
        selectedDetectionIDs = []
        selectedInputRange = nil
        analysisState = .idle
        localAIUnavailableAfterAnalysis = false
        restoredCopyFeedbackVisible = false
    }

    private func openSystemSettings() {
        guard let settingsURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) else {
            return
        }

        NSWorkspace.shared.open(settingsURL)
    }

    private func setLocalAIEnabled(_ isEnabled: Bool) {
        useLocalAIDetection = isEnabled
        localAIAvailability = localAIDetector.availability

        if !isEnabled {
            analyzedMatches.removeAll { $0.source == .localAI }
            localAIUnavailableAfterAnalysis = false

            if analysisState == .complete {
                refreshPreview()
            } else if analysisState == .analyzing {
                analysisState = inputText.isEmpty ? .idle : .stale
            }
            return
        }

        // Enabling the optional stage makes the existing result incomplete
        // until the user explicitly analyzes the text again.
        if analysisState == .complete {
            analysisState = .stale
            analyzedMatches = []
            detectedItems = []
            inputHighlights = []
            selectedDetectionIDs = []
        } else if analysisState == .analyzing {
            analysisState = inputText.isEmpty ? .idle : .stale
        }
    }

    private func analyzeText() {
        guard !inputText.isEmpty else {
            analysisState = .idle
            return
        }

        let sourceSnapshot = inputText
        let shouldUseLocalAI = useLocalAIDetection
        analysisState = .analyzing
        analyzedMatches = []
        detectedItems = []
        inputHighlights = []
        selectedDetectionIDs = []
        localAIUnavailableAfterAnalysis = false

        Task { @MainActor in
            var matches = anonymizer.detectMatches(in: sourceSnapshot)
            var localAIUnavailable = false

            if shouldUseLocalAI {
                let result = await localAIDetector.detect(in: sourceSnapshot)
                localAIAvailability = result.availability
                matches.append(contentsOf: result.matches)
                localAIUnavailable = !result.availability.isAvailable
            }

            // A source edit invalidates this task. The input observer has
            // already cleared the stale result and updated the status.
            guard inputText == sourceSnapshot,
                  useLocalAIDetection == shouldUseLocalAI else {
                return
            }

            analyzedMatches = matches
            localAIUnavailableAfterAnalysis = localAIUnavailable

            let initialResult = anonymizer.anonymizeWithResult(
                sourceSnapshot,
                enabledCategories: enabledCategories,
                manualDetections: manualDetections,
                detectedMatches: matches
            )
            selectedDetectionIDs = Set(initialResult.detectedItems.map(\.id))
            analysisState = .complete
            refreshPreview()
        }
    }

    private func refreshPreview() {
        guard !inputText.isEmpty else {
            detectedItems = []
            inputHighlights = []
            return
        }

        let result = anonymizer.anonymizeWithResult(
            inputText,
            enabledCategories: enabledCategories,
            selectedDetectionIDs: selectedDetectionIDs,
            manualDetections: manualDetections,
            detectedMatches: analyzedMatches
        )
        detectedItems = result.detectedItems
        inputHighlights = result.detectionHighlights(for: analysisState)
    }

    private func anonymizeInput() {
        guard analysisState == .complete else {
            return
        }

        let result = anonymizer.anonymizeWithResult(
            inputText,
            enabledCategories: enabledCategories,
            selectedDetectionIDs: selectedDetectionIDs,
            manualDetections: manualDetections,
            detectedMatches: analyzedMatches
        )
        outputText = result.anonymizedText
        detectedItems = result.detectedItems
        inputHighlights = result.detectionHighlights(for: analysisState)
        anonymizationSession = AnonymizationSession(result: result)
        restorationResult = nil
        restoredCopyFeedbackVisible = false
    }

    private func restoreEditedTextFromRight() {
        guard let anonymizationSession else {
            return
        }

        guard !outputText.isEmpty else {
            return
        }

        let result = restorer.restore(
            outputText,
            using: anonymizationSession
        )
        restorationResult = result

        // Restored content is a new left-side source revision. Keep the active
        // mapping for subsequent restores, but never reuse old detections.
        inputText = result.restoredText
        detectedItems = []
        inputHighlights = []
        manualDetections = []
        analyzedMatches = []
        selectedDetectionIDs = []
        selectedInputRange = nil
        localAIUnavailableAfterAnalysis = false
        analysisState = inputText.isEmpty ? .idle : .stale
    }

    private func clearRestoreData() {
        anonymizationSession = nil
        outputText = ""
        restorationResult = nil
        restoredCopyFeedbackVisible = false
    }

    private func clearExternalText() {
        outputText = ""
        restorationResult = nil
    }

    private func copyAnonymizedText() {
        guard ClipboardService.copy(outputText) else {
            return
        }
        anonymizedCopyFeedbackVisible = true
        anonymizedCopyFeedbackGeneration += 1
        let generation = anonymizedCopyFeedbackGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard generation == anonymizedCopyFeedbackGeneration else {
                return
            }
            anonymizedCopyFeedbackVisible = false
        }
    }

    private func copyInternalText() {
        guard ClipboardService.copy(inputText) else {
            return
        }
        restoredCopyFeedbackVisible = true
        restoredCopyFeedbackGeneration += 1
        let generation = restoredCopyFeedbackGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard generation == restoredCopyFeedbackGeneration else {
                return
            }
            restoredCopyFeedbackVisible = false
        }
    }
}

#Preview {
    ContentView()
}
