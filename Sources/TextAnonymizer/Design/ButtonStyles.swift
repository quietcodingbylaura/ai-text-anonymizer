import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, AppTheme.standardSpacing)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(
                Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .padding(.horizontal, compact ? 8 : AppTheme.standardSpacing)
            .padding(.vertical, compact ? 4 : 7)
            .foregroundStyle(.primary)
            .background(
                AppTheme.secondarySurface.opacity(configuration.isPressed ? 0.65 : 0.9),
                in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius)
                    .stroke(AppTheme.cardBorder)
            }
    }
}
