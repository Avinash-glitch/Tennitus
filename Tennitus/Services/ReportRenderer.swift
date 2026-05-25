import Foundation
import UIKit

enum ReportRenderer {
    static func generate(rangeDays: Int, store: AppStore) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tennitus-Report-\(rangeDays)-days.pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Tennitus Report",
            kCGPDFContextCreator as String: "Tennitus"
        ]

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        try renderer.writePDF(to: url) { context in
            context.beginPage()

            var y: CGFloat = 48
            draw("Tennitus Report", font: .boldSystemFont(ofSize: 28), x: 48, y: y)
            y += 42
            draw("Date range: last \(rangeDays) days", font: .systemFont(ofSize: 13), x: 48, y: y)
            y += 24
            draw("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))", font: .systemFont(ofSize: 13), x: 48, y: y)
            y += 36

            drawSection("Tinnitus profile", y: &y)
            draw("Laterality: \(store.profile.laterality.rawValue)", x: 48, y: y)
            y += 20
            draw("Sound type: \(store.profile.soundType.rawValue)", x: 48, y: y)
            y += 20
            
            let subtype = store.detectedSubtype
            draw("Pattern Profile: \(subtype.primary.rawValue)", x: 48, y: y)
            y += 20
            
            if let pitch = subtype.pitchHz {
                let pitchStr = pitch >= 1000 ? String(format: "%.1f kHz", pitch / 1000.0) : "\(Int(pitch)) Hz"
                draw("Matched Pitch: \(pitchStr)", x: 48, y: y)
                y += 20
            }
            
            let modifiersStr = subtype.modifiers.isEmpty ? "None" : subtype.modifiers.map { $0.rawValue }.sorted().joined(separator: ", ")
            draw("Active Modifiers: \(modifiersStr)", x: 48, y: y)
            y += 20
            
            draw("Profile Confidence: \(subtype.confidence.rawValue)", x: 48, y: y)
            y += 20
            
            draw("Baseline loudness: \(store.profile.baselineLoudness)/10", x: 48, y: y)
            y += 20
            draw("Baseline distress: \(store.profile.baselineDistress)/10", x: 48, y: y)
            y += 34

            drawSection("Weekly insight", y: &y)
            drawWrapped(store.weeklyInsight.headline, x: 48, y: &y, width: 500, font: .boldSystemFont(ofSize: 14))
            y += 10
            for observation in store.weeklyInsight.observations {
                drawWrapped("- \(observation)", x: 48, y: &y, width: 500)
            }
            y += 20

            drawSection("Data summary", y: &y)
            draw("Check-ins: \(store.checkIns.count)", x: 48, y: y)
            y += 20
            draw("Spike logs: \(store.spikes.count)", x: 48, y: y)
            y += 20
            draw("Signal lab events: \(store.audioEvents.count)", x: 48, y: y)
            y += 20
            draw("Insight confidence: \(store.weeklyInsight.confidence)", x: 48, y: y)
            y += 34

            if !store.audioEvents.isEmpty {
                drawSection("Signal lab summary", y: &y)
                for event in store.audioEvents.prefix(3) {
                    drawWrapped(
                        "- \(event.recordedAt.formatted(date: .abbreviated, time: .shortened)): selected \(formatTime(event.selectedStartSeconds))-\(formatTime(event.selectedEndSeconds)), dominant band \(event.analysis.dominantBandLabel), matched tone \(Int(event.tinnitusMatchFrequencyHz)) Hz, suggestion \(event.localSuggestion.title).",
                        x: 48,
                        y: &y,
                        width: 500
                    )
                }
                y += 20
            }

            drawSection("Clinical caveat", y: &y)
            drawWrapped(
                "This report is based on self-reported tracking data. It is not a diagnosis, treatment recommendation, or medical assessment.",
                x: 48,
                y: &y,
                width: 500
            )
        }

        return url
    }

    private static func drawSection(_ text: String, y: inout CGFloat) {
        draw(text, font: .boldSystemFont(ofSize: 16), x: 48, y: y)
        y += 24
    }

    private static func draw(_ text: String, font: UIFont = .systemFont(ofSize: 12), x: CGFloat, y: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    }

    private static func drawWrapped(_ text: String, x: CGFloat, y: inout CGFloat, width: CGFloat, font: UIFont = .systemFont(ofSize: 12)) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph
        ]
        let rect = CGRect(x: x, y: y, width: width, height: 120)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        let measured = text.boundingRect(with: CGSize(width: width, height: 120), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        y += ceil(measured.height) + 8
    }

    private static func formatTime(_ seconds: Double) -> String {
        let totalTenths = Int((seconds * 10).rounded())
        return "\(totalTenths / 10).\(totalTenths % 10)s"
    }
}
