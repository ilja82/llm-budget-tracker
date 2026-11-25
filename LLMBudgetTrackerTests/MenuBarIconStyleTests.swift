import AppKit
import XCTest

final class MenuBarIconStyleTests: XCTestCase {
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "MenuBarIconStyleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private struct Pixel {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    private struct Raster {
        let width: Int
        let height: Int
        let at: (Int, Int) -> Pixel
    }

    private func pixels(of image: NSImage) throws -> Raster {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return Raster(width: width, height: height, at: { x, y in
            let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
            return Pixel(
                red: color?.redComponent ?? 0, green: color?.greenComponent ?? 0,
                blue: color?.blueComponent ?? 0, alpha: color?.alphaComponent ?? 0
            )
        })
    }

    private func inkedPixelCount(
        of image: NSImage,
        xRange: Range<Int>? = nil,
        minimumAlpha: Double = 0.5
    ) throws -> Int {
        let raster = try pixels(of: image)
        let range = xRange ?? 0..<raster.width
        var count = 0
        for x in range where x < raster.width {
            for y in 0..<raster.height where raster.at(x, y).alpha > minimumAlpha {
                count += 1
            }
        }
        return count
    }

    private func pacingColoredPixelCount(of image: NSImage, xRange: Range<Int>) throws -> Int {
        let raster = try pixels(of: image)
        var count = 0
        for x in xRange where x < raster.width {
            for y in 0..<raster.height {
                let pixel = raster.at(x, y)
                if pixel.alpha > 0.9 && pixel.red > 0.8 && pixel.green < 0.25 && pixel.blue < 0.25 {
                    count += 1
                }
            }
        }
        return count
    }

    private var pacingColor: NSColor {
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    }

    func testCasesIdsLabelsAndDefault() {
        XCTAssertEqual(MenuBarIconStyle.allCases, [.bar, .ring, .dot, .textOnly, .line, .coloredText])
        XCTAssertEqual(Set(MenuBarIconStyle.allCases.map(\.id)).count, 6)
        for style in MenuBarIconStyle.allCases {
            XCTAssertFalse(style.label.isEmpty)
        }
        XCTAssertEqual(MenuBarIconStyle(storedValue: nil), .bar)
    }

    func testColoredTextStyleStorage() {
        XCTAssertEqual(MenuBarIconStyle.coloredText.label, "Colored text")
        XCTAssertEqual(MenuBarIconStyle(storedValue: "coloredText"), .coloredText)
        XCTAssertEqual(MenuBarIconStyle(storedValue: "unknown"), .bar)
    }

    func testMissingStoredValueLoadsBar() throws {
        XCTAssertEqual(MenuBarIconStyle.load(from: try makeDefaults()), .bar)
    }

    func testUnknownStoredValueLoadsBar() throws {
        let defaults = try makeDefaults()
        for raw in ["", "hexagon", "Ring"] {
            defaults.set(raw, forKey: StorageKeys.App.iconStyle)
            XCTAssertEqual(MenuBarIconStyle.load(from: defaults), .bar, raw)
        }
    }

    func testEveryStyleRoundTripsThroughStorageKey() throws {
        let defaults = try makeDefaults()
        for style in MenuBarIconStyle.allCases {
            style.save(to: defaults)
            XCTAssertEqual(defaults.string(forKey: StorageKeys.App.iconStyle), style.rawValue)
            XCTAssertEqual(MenuBarIconStyle.load(from: defaults), style)
        }
    }

    func testStorageKeyIsWipedOnReset() {
        XCTAssertTrue(StorageKeys.allKeys.contains(StorageKeys.App.iconStyle))
    }

    func testRendererReturnsStatusBarHeightImageForEveryStyle() throws {
        for style in MenuBarIconStyle.allCases {
            for progress in [0.0, 0.5, 1.0] {
                let image = MenuBarIconRenderer.image(style: style, progress: progress, color: .systemGreen, label: "")
                XCTAssertEqual(image.size.height, NSStatusBar.system.thickness, "\(style)")
                XCTAssertGreaterThan(image.size.width, 0, "\(style)")
                if style != .textOnly && style != .coloredText {
                    XCTAssertGreaterThan(try inkedPixelCount(of: image, minimumAlpha: 0), 0, "\(style) \(progress)")
                }
            }
        }
    }

    func testBarDrawsAtEveryProgress() throws {
        for progress in [0.0, 0.5, 1.0] {
            let image = MenuBarIconRenderer.image(style: .bar, progress: progress, color: pacingColor, label: "")
            XCTAssertGreaterThan(try inkedPixelCount(of: image), 0, "\(progress)")
        }
    }

    func testRingCoverageGrowsWithProgress() throws {
        let glyphArea = 0..<Int(NSStatusBar.system.thickness)
        let counts = try [0.0, 0.5, 1.0].map { progress -> Int in
            let image = MenuBarIconRenderer.image(style: .ring, progress: progress, color: pacingColor, label: "")
            return try pacingColoredPixelCount(of: image, xRange: glyphArea)
        }
        XCTAssertEqual(counts[0], 0)
        XCTAssertGreaterThan(counts[1], 0)
        XCTAssertGreaterThan(counts[2], counts[1])
    }

    func testRingAndDotDrawLabelPixels() throws {
        let glyphWidth = Int(NSStatusBar.system.thickness)
        for style in [MenuBarIconStyle.ring, .dot] {
            let image = MenuBarIconRenderer.image(style: style, progress: 0.5, color: pacingColor, label: "$12.34")
            let labelArea = glyphWidth..<Int(image.size.width)
            XCTAssertGreaterThan(try inkedPixelCount(of: image, xRange: labelArea), 0, "\(style)")
        }
    }

    func testRingAndDotDrawPacingColorInGlyphArea() throws {
        let glyphArea = 0..<Int(NSStatusBar.system.thickness)
        for style in [MenuBarIconStyle.ring, .dot] {
            let image = MenuBarIconRenderer.image(style: style, progress: 1, color: pacingColor, label: "42%")
            XCTAssertGreaterThan(try pacingColoredPixelCount(of: image, xRange: glyphArea), 0, "\(style)")
        }
    }

    func testRingProgressChangesDrawing() throws {
        let glyphArea = 0..<Int(NSStatusBar.system.thickness)
        let empty = MenuBarIconRenderer.image(style: .ring, progress: 0, color: pacingColor, label: "")
        let full = MenuBarIconRenderer.image(style: .ring, progress: 1, color: pacingColor, label: "")
        XCTAssertEqual(try pacingColoredPixelCount(of: empty, xRange: glyphArea), 0)
        XCTAssertGreaterThan(try pacingColoredPixelCount(of: full, xRange: glyphArea), 0)
    }

    func testLabelIsRenderedAndWidensImage() throws {
        for style in MenuBarIconStyle.allCases {
            let withoutLabel = MenuBarIconRenderer.image(style: style, progress: 0.5, color: pacingColor, label: "")
            let withLabel = MenuBarIconRenderer.image(style: style, progress: 0.5, color: pacingColor, label: "$12.34")
            XCTAssertGreaterThan(withLabel.size.width, 0, "\(style)")
            if style != .bar {
                XCTAssertGreaterThan(withLabel.size.width, withoutLabel.size.width, "\(style)")
            }
        }
        let text = MenuBarIconRenderer.image(style: .textOnly, progress: 0.5, color: pacingColor, label: "$12.34")
        XCTAssertGreaterThan(try inkedPixelCount(of: text), 0)
        let blank = MenuBarIconRenderer.image(style: .textOnly, progress: 0.5, color: pacingColor, label: "")
        XCTAssertEqual(try inkedPixelCount(of: blank), 0)
    }

    func testStylesDrawDifferently() throws {
        let bar = MenuBarIconRenderer.image(style: .bar, progress: 1, color: pacingColor, label: "")
        let dot = MenuBarIconRenderer.image(style: .dot, progress: 1, color: pacingColor, label: "")
        let barInk = try inkedPixelCount(of: bar)
        let dotInk = try inkedPixelCount(of: dot)
        XCTAssertNotEqual(barInk, dotInk)
    }

    private func solidInk(of image: NSImage) throws -> [Pixel] {
        let raster = try pixels(of: image)
        var ink: [Pixel] = []
        for x in 0..<raster.width {
            for y in 0..<raster.height {
                let pixel = raster.at(x, y)
                if pixel.alpha > 0.9 { ink.append(pixel) }
            }
        }
        return ink
    }

    private func inkMask(of image: NSImage) throws -> [Bool] {
        let raster = try pixels(of: image)
        var mask: [Bool] = []
        for x in 0..<raster.width {
            for y in 0..<raster.height {
                mask.append(raster.at(x, y).alpha > 0.9)
            }
        }
        return mask
    }

    private func swatch(of color: NSColor) throws -> Pixel {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
        return try pixels(of: image).at(2, 2)
    }

    private func share(of ink: [Pixel], matching color: NSColor) throws -> Double {
        let reference = try swatch(of: color)
        let matching = ink.filter {
            abs($0.red - reference.red) < 0.06 && abs($0.green - reference.green) < 0.06
                && abs($0.blue - reference.blue) < 0.06
        }
        return Double(matching.count) / Double(max(ink.count, 1))
    }

    private func assertInkDominated(by color: NSColor, image: NSImage, _ message: String) throws {
        let ink = try solidInk(of: image)
        XCTAssertGreaterThan(ink.count, 0, message)
        XCTAssertGreaterThanOrEqual(try share(of: ink, matching: color), 0.9, message)
    }

    func testColoredTextDrawsLabelInPassedColor() throws {
        let colors: [NSColor] = [
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
            NSColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1),
            NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        ]
        for color in colors {
            let image = MenuBarIconRenderer.image(style: .coloredText, progress: 0.5, color: color, label: "$12.34")
            try assertInkDominated(by: color, image: image, "\(color)")
        }
        let blank = MenuBarIconRenderer.image(style: .coloredText, progress: 0.5, color: colors[0], label: "")
        XCTAssertEqual(try inkedPixelCount(of: blank, minimumAlpha: 0), 0)
    }

    func testColoredTextMatchesTextOnlyShapeAndTextOnlyStaysNeutral() throws {
        let colored = MenuBarIconRenderer.image(style: .coloredText, progress: 0.5, color: pacingColor, label: "$12.34")
        let plain = MenuBarIconRenderer.image(style: .textOnly, progress: 0.5, color: pacingColor, label: "$12.34")
        XCTAssertEqual(colored.size, plain.size)
        XCTAssertFalse(colored.isTemplate)
        XCTAssertEqual(try inkMask(of: colored), try inkMask(of: plain))
        let plainInk = try solidInk(of: plain)
        XCTAssertGreaterThan(plainInk.count, 0)
        XCTAssertGreaterThanOrEqual(try share(of: plainInk, matching: .labelColor), 0.9)
        XCTAssertEqual(try pacingColoredPixelCount(of: plain, xRange: 0..<Int(plain.size.width)), 0)
    }

    func testPacingStatusColorsFeedColoredText() throws {
        let expected: [(PacingStatus, NSColor)] = [
            (.underPace, .systemGreen), (.onTrack, .systemGreen), (.nearLimit, .systemOrange),
            (.overPace, .systemRed), (.unknown, .systemGray)
        ]
        for (status, color) in expected {
            XCTAssertEqual(status.nsColor, color, "\(status)")
            let image = MenuBarIconRenderer.image(
                style: .coloredText, progress: 0.5, color: status.nsColor, label: "42%"
            )
            try assertInkDominated(by: color, image: image, "\(status)")
        }
    }

    func testColoredTextTintsOfflineHourglassGray() throws {
        let image = MenuBarIconRenderer.image(
            style: .coloredText, progress: 0, color: PacingStatus.unknown.nsColor, label: "\u{23F3}"
        )
        try assertInkDominated(by: .systemGray, image: image, "offline label")
    }
}
