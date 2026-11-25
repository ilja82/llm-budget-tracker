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

    private struct HueCounts {
        var red = 0
        var orange = 0
        var green = 0
    }

    private func hueCounts(of image: NSImage) throws -> HueCounts {
        let raster = try pixels(of: image)
        var counts = HueCounts()
        for x in 0..<raster.width {
            for y in 0..<raster.height {
                let pixel = raster.at(x, y)
                guard pixel.alpha > 0.9 else { continue }
                if pixel.red > 0.8 && pixel.green < 0.25 && pixel.blue < 0.25 { counts.red += 1 }
                if pixel.red > 0.8 && (0.4..<0.65).contains(pixel.green) && pixel.blue < 0.25 { counts.orange += 1 }
                if pixel.green > 0.8 && pixel.red < 0.25 && pixel.blue < 0.25 { counts.green += 1 }
            }
        }
        return counts
    }

    func testColoredTextDrawsLabelInPassedColor() throws {
        let red = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let orange = NSColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 1)
        let green = NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        let redCounts = try hueCounts(of: MenuBarIconRenderer.image(
            style: .coloredText, progress: 0.5, color: red, label: "$12.34"))
        XCTAssertGreaterThan(redCounts.red, 0)
        XCTAssertEqual(redCounts.orange + redCounts.green, 0)
        let orangeCounts = try hueCounts(of: MenuBarIconRenderer.image(
            style: .coloredText, progress: 0.5, color: orange, label: "$12.34"))
        XCTAssertGreaterThan(orangeCounts.orange, 0)
        XCTAssertEqual(orangeCounts.red + orangeCounts.green, 0)
        let greenCounts = try hueCounts(of: MenuBarIconRenderer.image(
            style: .coloredText, progress: 0.5, color: green, label: "$12.34"))
        XCTAssertGreaterThan(greenCounts.green, 0)
        XCTAssertEqual(greenCounts.red + greenCounts.orange, 0)
        let blank = MenuBarIconRenderer.image(style: .coloredText, progress: 0.5, color: red, label: "")
        XCTAssertEqual(try inkedPixelCount(of: blank, minimumAlpha: 0), 0)
    }

    func testColoredTextMatchesTextOnlyWidthAndTextOnlyStaysNeutral() throws {
        let colored = MenuBarIconRenderer.image(style: .coloredText, progress: 0.5, color: pacingColor, label: "$12.34")
        let plain = MenuBarIconRenderer.image(style: .textOnly, progress: 0.5, color: pacingColor, label: "$12.34")
        XCTAssertEqual(colored.size, plain.size)
        XCTAssertEqual(try pacingColoredPixelCount(of: plain, xRange: 0..<Int(plain.size.width)), 0)
        XCTAssertFalse(colored.isTemplate)
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
            XCTAssertGreaterThan(try inkedPixelCount(of: image), 0, "\(status)")
        }
    }
}
