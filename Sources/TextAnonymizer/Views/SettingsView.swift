import SwiftUI

struct SettingsView: View {
    @Binding private var enabledCategories: Set<ReplacementCategory>
    @Binding private var useLocalAIDetection: Bool

    let localAIAvailability: LocalAIAvailability
    let onCategoryChange: () -> Void
    let onLocalAIChange: (Bool) -> Void
    let onOpenSystemSettings: () -> Void

    init(
        enabledCategories: Binding<Set<ReplacementCategory>>,
        useLocalAIDetection: Binding<Bool>,
        localAIAvailability: LocalAIAvailability,
        onCategoryChange: @escaping () -> Void,
        onLocalAIChange: @escaping (Bool) -> Void,
        onOpenSystemSettings: @escaping () -> Void
    ) {
        _enabledCategories = enabledCategories
        _useLocalAIDetection = useLocalAIDetection
        self.localAIAvailability = localAIAvailability
        self.onCategoryChange = onCategoryChange
        self.onLocalAIChange = onLocalAIChange
        self.onOpenSystemSettings = onOpenSystemSettings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
                        AppSectionHeader(
                            "Anonymization Categories",
                            subtitle: "Choose which detected categories should be replaced."
                        )

                        HStack(spacing: AppTheme.controlSpacing) {
                            Button("Select All") {
                                enabledCategories = ReplacementCategory.allCategories
                                onCategoryChange()
                            }
                            .buttonStyle(SecondaryButtonStyle(compact: true))

                            Button("Select None") {
                                enabledCategories = []
                                onCategoryChange()
                            }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)],
                            alignment: .leading,
                            spacing: AppTheme.controlSpacing
                        ) {
                            ForEach(ReplacementCategory.allCases, id: \.self) { category in
                                Toggle(
                                    category.localizedDisplayName,
                                    isOn: categoryBinding(for: category)
                                )
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
                        AppSectionHeader(
                            "Local AI Detection",
                            subtitle: "Optional on-device support for difficult natural-language cases."
                        )

                        Toggle(
                            "Use Local AI Detection",
                            isOn: Binding(
                                get: { useLocalAIDetection },
                                set: { isEnabled in
                                    useLocalAIDetection = isEnabled
                                    onLocalAIChange(isEnabled)
                                }
                            )
                        )
                        .toggleStyle(.checkbox)

                        HStack(alignment: .top, spacing: AppTheme.controlSpacing) {
                            Image(systemName: localAIAvailability.isAvailable
                                ? "checkmark.circle"
                                : "info.circle")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: AppTheme.compactSpacing / 2) {
                                Text(localAIAvailability.localizedDisplayName)
                                    .font(.callout.weight(.medium))
                                Text(localAIAvailability.localizedDetail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                if let settingsGuidance = localAIAvailability.localizedSettingsGuidance {
                                    Text(settingsGuidance)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                if localAIAvailability.canOpenSystemSettings {
                                    Button("Open System Settings") {
                                        onOpenSystemSettings()
                                    }
                                    .buttonStyle(SecondaryButtonStyle(compact: true))
                                    .padding(.top, AppTheme.compactSpacing / 2)
                                }
                            }
                        }

                        Text("Local AI Detection uses Apple's on-device Foundation Model when available. No network fallback is used.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(AppTheme.pagePadding)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 560, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func categoryBinding(for category: ReplacementCategory) -> Binding<Bool> {
        Binding(
            get: {
                enabledCategories.contains(category)
            },
            set: { isEnabled in
                if isEnabled {
                    enabledCategories.insert(category)
                } else {
                    enabledCategories.remove(category)
                }
                onCategoryChange()
            }
        )
    }
}
