import AppKit
import SwiftUI

struct SelectableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var highlights: [DetectionHighlight]
    let onSelectionChange: (NSRange?) -> Void
    let onMarkSelection: (ReplacementCategory, NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSelectionChange: onSelectionChange,
            onMarkSelection: onMarkSelection
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = MarkingTextView()
        textView.delegate = context.coordinator
        textView.onMarkSelection = { category, range in
            context.coordinator.onMarkSelection(category, range)
        }
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onMarkSelection = onMarkSelection

        if textView.string != text {
            synchronizeText(textView, in: scrollView)
        }

        applyHighlights(to: textView, in: scrollView)
    }

    private func synchronizeText(_ textView: NSTextView, in scrollView: NSScrollView) {
        let oldSelection = textView.selectedRange()
        let oldScrollOrigin = scrollView.contentView.bounds.origin
        textView.string = text

        let textLength = text.utf16.count
        let location = min(oldSelection.location, textLength)
        let length = min(oldSelection.length, textLength - location)
        textView.setSelectedRange(NSRange(location: location, length: length))
        scrollView.contentView.scroll(to: oldScrollOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func applyHighlights(to textView: NSTextView, in scrollView: NSScrollView) {
        let selectedRange = textView.selectedRange()
        let scrollOrigin = scrollView.contentView.bounds.origin
        guard let storage = textView.textStorage else {
            return
        }
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: fullRange)

        for highlight in highlights {
            let range = highlight.range
            guard range.location >= 0,
                  range.length > 0,
                  NSMaxRange(range) <= storage.length else {
                continue
            }

            storage.addAttribute(
                .backgroundColor,
                value: highlight.isActive
                    ? AppTheme.activeDetectionHighlight
                    : AppTheme.inactiveDetectionHighlight,
                range: range
            )
        }
        storage.endEditing()

        // Attribute-only updates must not disturb the native editing state.
        textView.setSelectedRange(selectedRange)
        scrollView.contentView.scroll(to: scrollOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>
        var onSelectionChange: (NSRange?) -> Void
        var onMarkSelection: (ReplacementCategory, NSRange) -> Void
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            onSelectionChange: @escaping (NSRange?) -> Void,
            onMarkSelection: @escaping (ReplacementCategory, NSRange) -> Void
        ) {
            self.text = text
            self.onSelectionChange = onSelectionChange
            self.onMarkSelection = onMarkSelection
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else {
                return
            }
            if text.wrappedValue != textView.string {
                text.wrappedValue = textView.string
            }
            onSelectionChange(selectedRange(in: textView))
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else {
                return
            }
            onSelectionChange(selectedRange(in: textView))
        }

        @MainActor
        private func selectedRange(in textView: NSTextView) -> NSRange? {
            let range = textView.selectedRange()
            return range.length > 0 ? range : nil
        }
    }
}

private final class MarkingTextView: NSTextView {
    private static let manualMarkingMenuIdentifier = NSUserInterfaceItemIdentifier(
        "textanonymizer.mark-selection-as-sensitive"
    )
    private static let manualMarkingSeparatorIdentifier = NSUserInterfaceItemIdentifier(
        "textanonymizer.mark-selection-separator"
    )

    var onMarkSelection: ((ReplacementCategory, NSRange) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        removeManualMarkingItems(from: menu)

        // Preserve the native text actions and add manual marking only when
        // the user has an actual selection.
        guard selectedRange().length > 0 else {
            return menu
        }

        let categoryMenu = NSMenu(title: String(localized: "Mark as Sensitive"))
        for category in ReplacementCategory.manualCategories {
            let item = NSMenuItem(
                title: category.localizedDisplayName,
                action: #selector(markSelectionAsSensitive(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = category.rawValue
            categoryMenu.addItem(item)
        }

        let markItem = NSMenuItem(
            title: String(localized: "Mark as Sensitive"),
            action: nil,
            keyEquivalent: ""
        )
        markItem.identifier = Self.manualMarkingMenuIdentifier
        markItem.submenu = categoryMenu

        let separator = NSMenuItem.separator()
        separator.identifier = Self.manualMarkingSeparatorIdentifier
        menu.insertItem(markItem, at: 0)
        menu.insertItem(separator, at: 1)
        return menu
    }

    @objc
    private func markSelectionAsSensitive(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let category = ReplacementCategory(rawValue: rawValue) else {
            return
        }

        let range = selectedRange()
        guard range.length > 0 else {
            return
        }

        onMarkSelection?(category, range)
    }

    private func removeManualMarkingItems(from menu: NSMenu) {
        for item in menu.items where item.identifier == Self.manualMarkingMenuIdentifier
            || item.identifier == Self.manualMarkingSeparatorIdentifier {
            menu.removeItem(item)
        }
    }
}
