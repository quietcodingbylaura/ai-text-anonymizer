import SwiftUI

struct AppSectionHeader: View {
    let title: Text
    let subtitle: Text?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
    }

    init(_ title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing / 2) {
            title
                .font(.headline)

            if let subtitle {
                subtitle
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
