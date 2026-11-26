import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
            HStack {
                AppSectionHeader(
                    "Help",
                    subtitle: "Workflow and privacy information"
                )

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
                    helpCard(
                        title: "Anonymizing Text",
                        text: "Paste sensitive text into Internal Text. Analyze the text and review the detected items. Add manual detections if necessary. Anonymize the text to create a safe version on the right."
                    )

                    helpCard(
                        title: "External / AI Editing",
                        text: "Copy the anonymized text from the right side and edit it externally or with an AI tool. Keep placeholders unchanged."
                    ) {
                        placeholderExample
                    }

                    helpCard(
                        title: "Restoring Original Data",
                        text: "Paste the edited anonymized version back into the right editor. Restore replaces placeholders with the original values and writes the result to the left editor."
                    ) {
                        restoreExample
                    }

                    helpCard(
                        title: "Manual Marking",
                        text: "If something was not detected automatically, select it in Internal Text and use the right-click menu to mark it as sensitive. Choose the appropriate category. Manual detections use the same anonymization and Restore workflow."
                    )

                    helpCard(
                        title: "Privacy",
                        text: "Anonymization and restoration happen locally on this Mac. Restore mappings stay in the memory of the running app and are not stored permanently. Optional Local AI Detection uses Apple's on-device model when available and has no network fallback."
                    )

                    helpCard(
                        title: "Restore Mapping Lifetime",
                        text: "Restore data is available only during the current app session. Starting a new anonymization session may replace the previous mapping. Closing the app removes the mapping."
                    )
                }
            }

            Text("Developed and published by Laura Renning")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(AppTheme.pagePadding)
        .frame(minWidth: 560, minHeight: 620)
    }

    @ViewBuilder
    private func helpCard<Content: View>(
        title: LocalizedStringKey,
        text: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
                AppSectionHeader(title)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                content()
            }
        }
    }

    private var placeholderExample: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing / 2) {
            Text(verbatim: "[PERSON_1]")
            Text(verbatim: "[EMAIL_1]")
            Text(verbatim: "[ADDRESS_1]")
        }
        .font(.body.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }

    private var restoreExample: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing / 2) {
            Text(verbatim: "Julia Schneider")
            Text(verbatim: "→ [PERSON_1]")
            Text(verbatim: "→ external editing")
            Text(verbatim: "Tomorrow [PERSON_1] will handle the appointment.")
            Text(verbatim: "→")
            Text(verbatim: "Tomorrow Julia Schneider will handle the appointment.")
        }
        .font(.body.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }

    private func helpCard(
        title: LocalizedStringKey,
        text: LocalizedStringKey
    ) -> some View {
        helpCard(title: title, text: text) {
            EmptyView()
        }
    }
}
