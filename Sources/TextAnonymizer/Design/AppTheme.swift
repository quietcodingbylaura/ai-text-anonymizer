import AppKit
import SwiftUI

enum AppTheme {
    static let pagePadding: CGFloat = 24
    static let compactSpacing: CGFloat = 8
    static let controlSpacing: CGFloat = 10
    static let standardSpacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 18

    static let cornerRadius: CGFloat = 12
    static let innerCornerRadius: CGFloat = 8

    static let editorMinHeight: CGFloat = 180
    static let editorIdealHeight: CGFloat = 260
    static let editorMaxHeight: CGFloat = 380

    static let defaultWindowWidth: CGFloat = 1200
    static let defaultWindowHeight: CGFloat = 820
    static let minimumWindowWidth: CGFloat = 760
    static let minimumWindowHeight: CGFloat = 700
    static let wideLayoutBreakpoint: CGFloat = 980

    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.65)
    static let editorBackground = Color(nsColor: .textBackgroundColor)
    static let secondarySurface = Color(nsColor: .controlBackgroundColor)

    static let activeDetectionHighlight = NSColor.systemYellow.withAlphaComponent(0.32)
    static let inactiveDetectionHighlight = NSColor.systemYellow.withAlphaComponent(0.14)
}
