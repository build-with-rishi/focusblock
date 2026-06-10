import AppKit
import EventKit

class OverlayContentView: NSView {
    private var eventTitle: String = ""
    private var timeLabel: String = ""
    private var startTimeLabel: String = ""
    private var durationLabel: String = ""

    func configure(event: EKEvent, minutesBefore: Int) {
        eventTitle = event.title ?? "Upcoming Event"

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

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let centerX = bounds.midX
        let centerY = bounds.midY

        // Event title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 52, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let titleSize = (eventTitle as NSString).size(withAttributes: titleAttrs)
        (eventTitle as NSString).draw(
            at: NSPoint(x: centerX - titleSize.width / 2, y: centerY + 10),
            withAttributes: titleAttrs
        )

        // Time remaining
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: NSColor(white: 0.55, alpha: 1.0)
        ]
        let timeSize = (timeLabel as NSString).size(withAttributes: timeAttrs)
        (timeLabel as NSString).draw(
            at: NSPoint(x: centerX - timeSize.width / 2, y: centerY - 40),
            withAttributes: timeAttrs
        )

        // Start time
        let startAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor(white: 0.35, alpha: 1.0)
        ]
        let startFull = "\(startTimeLabel)  ·  \(durationLabel)"
        let startSize = (startFull as NSString).size(withAttributes: startAttrs)
        (startFull as NSString).draw(
            at: NSPoint(x: centerX - startSize.width / 2, y: centerY - 75),
            withAttributes: startAttrs
        )

        // Dismiss hint
        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(white: 0.2, alpha: 1.0)
        ]
        let hint = "click or press any key to dismiss"
        let hintSize = (hint as NSString).size(withAttributes: hintAttrs)
        (hint as NSString).draw(
            at: NSPoint(x: centerX - hintSize.width / 2, y: 40),
            withAttributes: hintAttrs
        )
    }
}
