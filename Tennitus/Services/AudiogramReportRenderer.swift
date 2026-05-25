import Foundation
import UIKit

enum AudiogramReportRenderer {
    static func generate(result: AudiogramScreeningResult) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tennitus-Audiogram-Screening.pdf")

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: url) { context in
            context.beginPage()

            var y: CGFloat = 44
            draw("Tennitus Audiogram Screening", font: .boldSystemFont(ofSize: 24), x: 44, y: y)
            y += 32
            draw("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))", x: 44, y: y)
            y += 18
            draw("Headphones: \(result.headphoneModel)", x: 44, y: y)
            y += 18
            draw("Calibration: \(result.calibrationStatus)", x: 44, y: y)
            y += 30

            drawAudiogram(result: result, rect: CGRect(x: 54, y: y, width: 490, height: 280))
            y += 310

            drawSection("Summary", y: &y)
            drawSummary("Left", summary: result.leftSummary, x: 54, y: &y)
            y += 10
            drawSummary("Right", summary: result.rightSummary, x: 54, y: &y)
            y += 20

            drawSection("Caveat", y: &y)
            drawWrapped(
                "This is an indicative screening result, not a clinical diagnosis. Results depend on device, headphones, environment, user response, and calibration. Discuss hearing concerns with a qualified audiologist.",
                x: 54,
                y: &y,
                width: 490
            )
        }

        return url
    }

    private static func drawAudiogram(result: AudiogramScreeningResult, rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        defer { context?.restoreGState() }

        UIColor.systemGray5.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        let plot = rect.insetBy(dx: 42, dy: 28)
        UIColor.systemGray3.setStroke()
        UIBezierPath(rect: plot).stroke()

        for threshold in stride(from: -10, through: 120, by: 10) {
            let y = yPosition(dbHL: Double(threshold), plot: plot)
            UIColor.systemGray4.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
            path.stroke()
            draw("\(threshold)", font: .systemFont(ofSize: 8), x: rect.minX + 8, y: y - 5)
        }

        for frequency in AudiogramEngine.standardFrequencies {
            let x = xPosition(frequency: frequency, plot: plot)
            UIColor.systemGray4.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
            path.stroke()
            draw(label(for: frequency), font: .systemFont(ofSize: 8), x: x - 14, y: plot.maxY + 8)
        }

        drawPoints(result.points.filter { $0.ear == .left }, plot: plot, color: .systemBlue, marker: "X")
        drawPoints(result.points.filter { $0.ear == .right }, plot: plot, color: .systemRed, marker: "O")
        draw("dB HL", font: .systemFont(ofSize: 9), x: rect.minX + 8, y: rect.minY + 8)
        draw("Hz", font: .systemFont(ofSize: 9), x: plot.maxX - 10, y: plot.maxY + 26)
    }

    private static func drawPoints(_ points: [AudiogramThresholdPoint], plot: CGRect, color: UIColor, marker: String) {
        color.setStroke()
        let sorted = points.sorted { $0.frequencyHz < $1.frequencyHz }
        let path = UIBezierPath()
        for (index, point) in sorted.enumerated() {
            let cgPoint = CGPoint(
                x: xPosition(frequency: point.frequencyHz, plot: plot),
                y: yPosition(dbHL: point.thresholdDBHL, plot: plot)
            )
            if index == 0 {
                path.move(to: cgPoint)
            } else {
                path.addLine(to: cgPoint)
            }
            draw(marker, font: .boldSystemFont(ofSize: 12), color: color, x: cgPoint.x - 5, y: cgPoint.y - 8)
        }
        path.stroke()
    }

    private static func xPosition(frequency: Double, plot: CGRect) -> CGFloat {
        let low = log10(250.0)
        let high = log10(8_000.0)
        let ratio = (log10(frequency) - low) / (high - low)
        return plot.minX + plot.width * CGFloat(ratio)
    }

    private static func yPosition(dbHL: Double, plot: CGRect) -> CGFloat {
        let clamped = max(-10, min(120, dbHL))
        let ratio = (clamped + 10) / 130
        return plot.minY + plot.height * CGFloat(ratio)
    }

    private static func label(for frequency: Double) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }

    private static func drawSummary(_ ear: String, summary: AudiogramEarSummary, x: CGFloat, y: inout CGFloat) {
        draw("\(ear) ear", font: .boldSystemFont(ofSize: 13), x: x, y: y)
        y += 18
        draw("PTA4: \(format(summary.pta4DBHL)) dB HL - \(summary.pta4Tier.rawValue)", x: x, y: y)
        y += 18
        draw("High frequency average: \(format(summary.highFrequencyAverageDBHL)) dB HL", x: x, y: y)
        y += 18
        draw("Worst frequency tier: \(summary.worstFrequencyTier.rawValue)", x: x, y: y)
        y += 18
    }

    private static func format(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    private static func drawSection(_ text: String, y: inout CGFloat) {
        draw(text, font: .boldSystemFont(ofSize: 16), x: 54, y: y)
        y += 22
    }

    private static func draw(_ text: String, font: UIFont = .systemFont(ofSize: 11), color: UIColor = .label, x: CGFloat, y: CGFloat) {
        text.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func drawWrapped(_ text: String, x: CGFloat, y: inout CGFloat, width: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.label]
        let rect = CGRect(x: x, y: y, width: width, height: 90)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        let measured = text.boundingRect(with: CGSize(width: width, height: 90), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        y += measured.height + 8
    }
}
