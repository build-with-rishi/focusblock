import AppKit
import EventKit

class OverlayContentView: NSView {
    private var eventTitle: String = ""
    private var timeLabel: String = ""
    private var startTimeLabel: String = ""
    private var durationLabel: String = ""
    private var quote: String = ""
    private var challengeWord: String = ""
    private var typedCount: Int = 0

    func configure(event: EKEvent, minutesBefore: Int, quote: String, challengeWord: String) {
        eventTitle = event.title ?? "Upcoming Event"
        self.quote = quote
        self.challengeWord = challengeWord
        typedCount = 0

        switch minutesBefore {
        case 30: timeLabel = "in 30 minutes"
        case 10: timeLabel = "in 10 minutes"
        case 5:  timeLabel = "in 5 minutes"
        default: timeLabel = "starting soon"
        }

        if let start = event.startDate {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            startTimeLabel = formatter.string(from: start)
        }

        if let start = event.startDate, let end = event.endDate {
            let duration = Int(end.timeIntervalSince(start) / 60)
            if duration >= 60 {
                let hours = duration / 60
                let mins = duration % 60
                durationLabel = mins > 0 ? "\(hours)h \(mins)m" : "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                durationLabel = "\(duration) minutes"
            }
        }

        setNeedsDisplay(bounds)
    }

    func update(typedCount: Int) {
        self.typedCount = typedCount
        setNeedsDisplay(bounds)
    }

    private func drawCentered(_ text: String, attributes: [NSAttributedString.Key: Any], centerX: CGFloat, y: CGFloat) {
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: centerX - size.width / 2, y: y),
            withAttributes: attributes
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let centerX = bounds.midX
        let centerY = bounds.midY

        // Event title
        drawCentered(eventTitle, attributes: [
            .font: NSFont.systemFont(ofSize: 52, weight: .semibold),
            .foregroundColor: NSColor.white
        ], centerX: centerX, y: centerY + 110)

        // Time remaining
        drawCentered(timeLabel, attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: NSColor(white: 0.55, alpha: 1.0)
        ], centerX: centerX, y: centerY + 60)

        // Start time · duration
        drawCentered("\(startTimeLabel)  ·  \(durationLabel)", attributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor(white: 0.35, alpha: 1.0)
        ], centerX: centerX, y: centerY + 25)

        // Quote — wrapped and centered
        let quoteParagraph = NSMutableParagraphStyle()
        quoteParagraph.alignment = .center
        let quoteAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .regular).withItalics(),
            .foregroundColor: NSColor(white: 0.7, alpha: 1.0),
            .paragraphStyle: quoteParagraph
        ]
        let quoteText = "\u{201C}\(quote)\u{201D}" as NSString
        let quoteWidth = min(bounds.width - 200, 760)
        let quoteBounds = quoteText.boundingRect(
            with: NSSize(width: quoteWidth, height: 200),
            options: [.usesLineFragmentOrigin],
            attributes: quoteAttrs
        )
        quoteText.draw(
            in: NSRect(
                x: centerX - quoteWidth / 2,
                y: centerY - 50 - quoteBounds.height,
                width: quoteWidth,
                height: quoteBounds.height
            ),
            withAttributes: quoteAttrs
        )

        // Challenge word — typed letters bright, remaining letters dim
        let challenge = NSMutableAttributedString()
        let letterFont = NSFont.monospacedSystemFont(ofSize: 38, weight: .bold)
        for (index, letter) in challengeWord.uppercased().enumerated() {
            let color = index < typedCount ? NSColor.white : NSColor(white: 0.28, alpha: 1.0)
            challenge.append(NSAttributedString(string: String(letter), attributes: [
                .font: letterFont,
                .foregroundColor: color,
                .kern: 14
            ]))
        }
        let challengeSize = challenge.size()
        challenge.draw(at: NSPoint(x: centerX - challengeSize.width / 2, y: centerY - 175))

        // Dismiss hint
        drawCentered("type the word above to dismiss", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(white: 0.3, alpha: 1.0)
        ], centerX: centerX, y: 40)
    }
}

private extension NSFont {
    func withItalics() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
}
