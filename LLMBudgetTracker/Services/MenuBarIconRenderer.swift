import AppKit

enum MenuBarIconRenderer {
    static func image(
        style: MenuBarIconStyle,
        progress: Double,
        color: NSColor,
        label: String,
        linePosition: MenuBarLinePosition = .below
    ) -> NSImage {
        let clamped = CGFloat(min(1.0, max(0.0, progress)))
        switch style {
        case .bar: return barImage(progress: progress, color: color, label: label)
        case .ring: return ringImage(progress: clamped, color: color, label: label)
        case .dot: return dotImage(color: color, label: label)
        case .textOnly: return textImage(label: label)
        case .line: return lineImage(progress: clamped, color: color, label: label, position: linePosition)
        case .coloredText: return textImage(label: label, color: color)
        }
    }

    private static var height: CGFloat { NSStatusBar.system.thickness }

    private static func labelFont(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
    }

    private static func labelString(
        _ label: String,
        fontSize: CGFloat,
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        NSAttributedString(
            string: label,
            attributes: [.font: labelFont(size: fontSize), .foregroundColor: color]
        )
    }

    private static func glyphImage(
        glyphSize: CGFloat,
        label: String,
        drawGlyph: @escaping (CGRect) -> Void
    ) -> NSImage {
        let fontSize = ((height - 2) * 0.62).rounded()
        let text = labelString(label, fontSize: fontSize)
        let textSize = text.size()
        let gap: CGFloat = label.isEmpty ? 0 : 5
        let width = ceil(glyphSize + gap + textSize.width) + 8
        return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let glyphRect = CGRect(x: 4, y: (rect.height - glyphSize) / 2, width: glyphSize, height: glyphSize)
            drawGlyph(glyphRect)
            if !label.isEmpty {
                text.draw(at: NSPoint(x: glyphRect.maxX + gap, y: (rect.height - textSize.height) / 2))
            }
            return true
        }
    }

    private static func ringImage(progress: CGFloat, color: NSColor, label: String) -> NSImage {
        glyphImage(glyphSize: height - 6, label: label) { rect in
            let lineWidth: CGFloat = 2.5
            let ringRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let center = NSPoint(x: ringRect.midX, y: ringRect.midY)
            let radius = ringRect.width / 2

            let track = NSBezierPath(ovalIn: ringRect)
            track.lineWidth = lineWidth
            NSColor.quaternaryLabelColor.setStroke()
            track.stroke()

            guard progress > 0 else { return }
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90,
                endAngle: 90 - 360 * progress,
                clockwise: true
            )
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            color.setStroke()
            arc.stroke()
        }
    }

    private static func dotImage(color: NSColor, label: String) -> NSImage {
        glyphImage(glyphSize: 9, label: label) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private static func textImage(label: String, color: NSColor = .labelColor) -> NSImage {
        let fontSize = ((height - 2) * 0.62).rounded()
        let text = labelString(label, fontSize: fontSize, color: color)
        let textSize = text.size()
        let width = max(ceil(textSize.width) + 8, 16)
        return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            text.draw(at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2))
            return true
        }
    }

    private static func lineImage(
        progress: CGFloat,
        color: NSColor,
        label: String,
        position: MenuBarLinePosition
    ) -> NSImage {
        let lineHeight: CGFloat = 2
        let gap: CGFloat = 1
        let fontSize = ((height - 2) * 0.62).rounded()
        let text = labelString(label, fontSize: fontSize)
        let textSize = text.size()
        let width = max(ceil(textSize.width) + 8, 16)
        return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let lineY = position == .below ? 0 : rect.height - lineHeight
            let track = CGRect(x: 2, y: lineY, width: rect.width - 4, height: lineHeight)
            let trackPath = NSBezierPath(roundedRect: track, xRadius: lineHeight / 2, yRadius: lineHeight / 2)
            NSColor.quaternaryLabelColor.setFill()
            trackPath.fill()

            let fillWidth = track.width * progress
            if fillWidth > 0 {
                NSGraphicsContext.saveGraphicsState()
                trackPath.addClip()
                color.setFill()
                NSBezierPath(rect: CGRect(x: track.minX, y: track.minY, width: fillWidth, height: lineHeight)).fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            let textAreaHeight = rect.height - lineHeight - gap
            let textAreaY = position == .below ? lineHeight + gap : 0
            text.draw(at: NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: textAreaY + (textAreaHeight - textSize.height) / 2
            ))
            return true
        }
    }

    private static func barImage(progress: Double, color: NSColor, label: String) -> NSImage {
        let height: CGFloat = NSStatusBar.system.thickness
        let barH: CGFloat = height - 2
        let fontSize: CGFloat = (barH * 0.62).rounded()
        let textWidth = NSAttributedString(
            string: label,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)]
        ).size().width
        let width: CGFloat = max(textWidth + 16, 44)

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let barY = (rect.height - barH) / 2
            let barRect = CGRect(x: 0.5, y: barY, width: rect.width - 1, height: barH)
            let radius = barH / 4

            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()

            let fillW = barRect.width * CGFloat(min(1.0, max(0.0, progress)))
            if fillW > 0 {
                var fillRect = barRect
                fillRect.size.width = fillW
                color.withAlphaComponent(0.85).setFill()
                NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
            }

            let border = NSBezierPath(roundedRect: barRect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
            border.lineWidth = 1
            NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
            border.stroke()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
            let str = NSAttributedString(string: label, attributes: attrs)
            let sz = str.size()
            str.draw(at: NSPoint(x: (width - sz.width) / 2, y: barY + (barH - sz.height) / 2))

            return true
        }
    }
}
