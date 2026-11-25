import AppKit
import XCTest

final class MenuBarLineIconTests: XCTestCase {
    private struct Pixel: Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        var isGreen: Bool {
            alpha > 0.5 && green > red + 0.15 && green > blue + 0.15
        }

        var isGreyTrack: Bool {
            alpha > 0.02 && abs(red - green) < 0.1 && abs(green - blue) < 0.1 && abs(red - blue) < 0.1
        }
    }

    private struct Raster {
        let width: Int
        let height: Int
        let pixels: [[Pixel]]

        func at(_ x: Int, _ row: Int) -> Pixel { pixels[row][x] }
    }

    private let lineRows = 3

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "MenuBarLineIconTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func raster(of image: NSImage) throws -> Raster {
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
        let pixels = (0..<height).map { row in
            (0..<width).map { x -> Pixel in
                let color = rep.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB)
                return Pixel(
                    red: color?.redComponent ?? 0, green: color?.greenComponent ?? 0,
                    blue: color?.blueComponent ?? 0, alpha: color?.alphaComponent ?? 0
                )
            }
        }
        return Raster(width: width, height: height, pixels: pixels)
    }

    private func lineRowRange(_ raster: Raster, _ position: MenuBarLinePosition) -> Range<Int> {
        position == .below ? (raster.height - lineRows)..<raster.height : 0..<lineRows
    }

    private func otherRowRange(_ raster: Raster, _ position: MenuBarLinePosition) -> Range<Int> {
        position == .below ? 0..<(raster.height - lineRows) : lineRows..<raster.height
    }

    private func lineImage(
        progress: Double,
        color: NSColor = .systemGreen,
        label: String = "50%",
        position: MenuBarLinePosition = .below
    ) -> NSImage {
        MenuBarIconRenderer.image(
            style: .line, progress: progress, color: color, label: label, linePosition: position
        )
    }

    private func columnHasGreen(_ raster: Raster, x: Int, rows: Range<Int>) -> Bool {
        rows.contains { raster.at(x, $0).isGreen }
    }

    private func columnHasTrack(_ raster: Raster, x: Int, rows: Range<Int>) -> Bool {
        rows.contains { raster.at(x, $0).isGreyTrack && !raster.at(x, $0).isGreen }
    }

    private func greenCount(_ raster: Raster, rows: Range<Int>) -> Int {
        rows.reduce(0) { sum, row in
            sum + (0..<raster.width).filter { raster.at($0, row).isGreen }.count
        }
    }

    func testLineStyleCaseAndStorage() throws {
        XCTAssertEqual(MenuBarIconStyle.allCases, [.bar, .ring, .dot, .textOnly, .line, .coloredText])
        XCTAssertEqual(MenuBarIconStyle.line.rawValue, "line")
        XCTAssertEqual(MenuBarIconStyle.line.label, "Line")
        XCTAssertEqual(MenuBarIconStyle(storedValue: "line"), .line)
        XCTAssertEqual(MenuBarIconStyle(storedValue: "Line"), .bar)
        let defaults = try makeDefaults()
        MenuBarIconStyle.line.save(to: defaults)
        XCTAssertEqual(defaults.string(forKey: StorageKeys.App.iconStyle), "line")
        XCTAssertEqual(MenuBarIconStyle.load(from: defaults), .line)
    }

    func testLinePositionDefaultsToBelow() throws {
        XCTAssertEqual(MenuBarLinePosition.allCases, [.below, .above])
        XCTAssertEqual(MenuBarLinePosition.below.label, "Below")
        XCTAssertEqual(MenuBarLinePosition.above.label, "Above")
        XCTAssertEqual(MenuBarLinePosition(storedValue: nil), .below)
        XCTAssertEqual(MenuBarLinePosition.load(from: try makeDefaults()), .below)
        let defaults = try makeDefaults()
        for raw in ["", "top", "Above"] {
            defaults.set(raw, forKey: StorageKeys.App.linePosition)
            XCTAssertEqual(MenuBarLinePosition.load(from: defaults), .below, raw)
        }
    }

    func testLinePositionRoundTripsAndIsWipedOnReset() throws {
        XCTAssertEqual(StorageKeys.App.linePosition, "menuBarLinePosition")
        XCTAssertTrue(StorageKeys.allKeys.contains(StorageKeys.App.linePosition))
        let defaults = try makeDefaults()
        for position in MenuBarLinePosition.allCases {
            position.save(to: defaults)
            XCTAssertEqual(defaults.string(forKey: StorageKeys.App.linePosition), position.rawValue)
            XCTAssertEqual(MenuBarLinePosition.load(from: defaults), position)
        }
    }

    func testHalfProgressFillsLeftGreenAndRightTrack() throws {
        for position in MenuBarLinePosition.allCases {
            let raster = try raster(of: lineImage(progress: 0.5, position: position))
            let rows = lineRowRange(raster, position)
            let leftEnd = Int(Double(raster.width) * 0.4)
            let rightStart = Int((Double(raster.width) * 0.6).rounded(.up))
            for x in 4..<leftEnd {
                XCTAssertTrue(columnHasGreen(raster, x: x, rows: rows), "\(position) x=\(x)")
            }
            for x in rightStart..<(raster.width - 4) {
                XCTAssertFalse(columnHasGreen(raster, x: x, rows: rows), "\(position) x=\(x)")
                XCTAssertTrue(columnHasTrack(raster, x: x, rows: rows), "\(position) x=\(x)")
            }
            XCTAssertEqual(greenCount(raster, rows: otherRowRange(raster, position)), 0, "\(position)")
        }
    }

    func testZeroProgressDrawsOnlyTrack() throws {
        for position in MenuBarLinePosition.allCases {
            let raster = try raster(of: lineImage(progress: 0, position: position))
            let rows = lineRowRange(raster, position)
            XCTAssertEqual(greenCount(raster, rows: 0..<raster.height), 0, "\(position)")
            for x in 4..<(raster.width - 4) {
                XCTAssertTrue(columnHasTrack(raster, x: x, rows: rows), "\(position) x=\(x)")
            }
        }
    }

    func testFullProgressDrawsOnlyGreenInLine() throws {
        for position in MenuBarLinePosition.allCases {
            let raster = try raster(of: lineImage(progress: 1, position: position))
            let rows = lineRowRange(raster, position)
            for x in 4..<(raster.width - 4) {
                XCTAssertTrue(columnHasGreen(raster, x: x, rows: rows), "\(position) x=\(x)")
                XCTAssertFalse(columnHasTrack(raster, x: x, rows: rows), "\(position) x=\(x)")
            }
        }
    }

    func testProgressAboveOneIsClamped() throws {
        for position in MenuBarLinePosition.allCases {
            let full = try raster(of: lineImage(progress: 1, position: position))
            let over = try raster(of: lineImage(progress: 1.7, position: position))
            XCTAssertEqual(full.width, over.width)
            XCTAssertEqual(full.pixels, over.pixels, "\(position)")
        }
    }

    func testImageSizeFollowsLabel() {
        let thickness = NSStatusBar.system.thickness
        let fontSize = ((thickness - 2) * 0.62).rounded()
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        for label in ["", "7%", "$12.34", "$1,234.56"] {
            let textWidth = NSAttributedString(string: label, attributes: [.font: font]).size().width
            let image = lineImage(progress: 0.5, label: label)
            XCTAssertEqual(image.size.width, max(ceil(textWidth) + 8, 16), label)
            XCTAssertEqual(image.size.height, thickness, label)
        }
        XCTAssertEqual(lineImage(progress: 0.5, label: "").size.width, 16)
    }

    func testLabelDrawsOutsideLineRows() throws {
        for position in MenuBarLinePosition.allCases {
            let labelled = try raster(of: lineImage(progress: 0.5, label: "$12.34", position: position))
            let blank = try raster(of: lineImage(progress: 0.5, label: "", position: position))
            let ink: (Raster) -> Int = { raster in
                self.otherRowRange(raster, position).reduce(0) { sum, row in
                    sum + (0..<raster.width).filter { raster.at($0, row).alpha > 0.5 }.count
                }
            }
            XCTAssertGreaterThan(ink(labelled), 0, "\(position)")
            XCTAssertEqual(ink(blank), 0, "\(position)")
        }
    }

    func testOtherStylesIgnoreLinePosition() throws {
        for style in MenuBarIconStyle.allCases where style != .line {
            let below = MenuBarIconRenderer.image(
                style: style, progress: 0.5, color: .systemRed, label: "42%", linePosition: .below
            )
            let above = MenuBarIconRenderer.image(
                style: style, progress: 0.5, color: .systemRed, label: "42%", linePosition: .above
            )
            let fallback = MenuBarIconRenderer.image(style: style, progress: 0.5, color: .systemRed, label: "42%")
            XCTAssertEqual(try raster(of: below).pixels, try raster(of: above).pixels, "\(style)")
            XCTAssertEqual(try raster(of: below).pixels, try raster(of: fallback).pixels, "\(style)")
        }
    }

    private func swatch(_ color: NSColor) throws -> Pixel {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
        return try raster(of: image).at(1, 1)
    }

    private func fillMatchRatio(_ color: NSColor, position: MenuBarLinePosition) throws -> Double {
        let expected = try swatch(color)
        let half = try raster(of: lineImage(progress: 0.5, color: color, position: position))
        let full = try raster(of: lineImage(progress: 1, color: color, position: position))
        var total: CGFloat = 0
        var matching: CGFloat = 0
        for row in lineRowRange(half, position) {
            for x in 0..<(half.width / 2) {
                let weight = full.at(x, row).alpha
                guard weight > 0.02 else { continue }
                let pixel = half.at(x, row)
                total += weight
                let close = abs(pixel.red - expected.red) < 0.06
                    && abs(pixel.green - expected.green) < 0.06
                    && abs(pixel.blue - expected.blue) < 0.06
                if close { matching += min(pixel.alpha, weight) }
            }
        }
        XCTAssertGreaterThan(total, 4, "\(position)")
        return Double(matching / max(total, 0.0001))
    }

    func testFillTakesPassedColor() throws {
        for position in MenuBarLinePosition.allCases {
            for color in [NSColor.systemGreen, .systemOrange, .systemRed] {
                XCTAssertGreaterThanOrEqual(try fillMatchRatio(color, position: position), 0.9, "\(position) \(color)")
            }
        }
    }

    func testRedFillIsNotGreen() throws {
        let raster = try raster(of: lineImage(progress: 0.5, color: .systemRed))
        XCTAssertEqual(greenCount(raster, rows: 0..<raster.height), 0)
    }

    func testFillFollowsPacingStatusColor() throws {
        let statuses: [PacingStatus] = [.underPace, .onTrack, .nearLimit, .overPace, .unknown]
        let expected: [NSColor] = [.systemGreen, .systemGreen, .systemOrange, .systemRed, .systemGray]
        for (status, color) in zip(statuses, expected) {
            XCTAssertEqual(status.nsColor, color, "\(status)")
            for position in MenuBarLinePosition.allCases {
                XCTAssertGreaterThanOrEqual(
                    try fillMatchRatio(status.nsColor, position: position), 0.9, "\(status) \(position)"
                )
            }
        }
    }
}
