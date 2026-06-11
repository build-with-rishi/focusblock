import AudioToolbox
import SwiftUI

// The iOS counterpart of the macOS full-screen overlay. iOS apps cannot draw
// over other apps, so this takes over FocusBlock's OWN screen instead (it is
// presented as a fullScreenCover). Layout mirrors OverlayContentView.swift:
// black background, event title (medium), time-to-event HUGE, start time and
// duration (small), a quote, and the challenge word typed letter-by-letter.
struct ChallengeView: View {
    let request: ChallengeRequest
    let onDismiss: () -> Void

    @State private var typedCount = 0
    @State private var inputBuffer = ""
    @FocusState private var inputFocused: Bool
    @State private var alarmTimer: Timer?
    @State private var autoDismissTimer: Timer?

    // AVAudioPlayer can't be used without an audio file bundled in the app,
    // and we ship no resources — so the "looping alarm ringtone" is
    // approximated with AudioServicesPlaySystemSound(1005) (alarm.caf, a
    // sound ID that has existed since early iOS) re-fired by a Timer.
    // Limitations: it respects the silent switch, ignores the volume of the
    // ringer-vs-media split in subtle ways, and can't be a real ringtone.
    private let alarmSoundID: SystemSoundID = 1005

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Event title — medium prominence
                Text(request.eventTitle)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(white: 0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Time to event — the dominant element, ticking live
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(countdownText(now: context.date))
                        .font(.system(size: 88, weight: .heavy))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.top, 8)
                }

                // Start time · duration
                Text("\(startTimeText)  ·  \(durationText)")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(white: 0.4))
                    .padding(.top, 4)

                // Quote
                Text("\u{201C}\(request.quote)\u{201D}")
                    .font(.system(size: 20, weight: .medium))
                    .italic()
                    .foregroundColor(Color(white: 0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 36)

                // Challenge word — typed letters bright, remaining letters dim
                HStack(spacing: 12) {
                    ForEach(Array(request.challengeWord.uppercased().enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundColor(index < typedCount ? .white : Color(white: 0.28))
                    }
                }
                .padding(.top, 44)

                Text("type the word above to dismiss")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.3))
                    .padding(.top, 12)

                Spacer()
            }

            // Hidden text field that owns the keyboard. Every character the
            // user types lands in inputBuffer and is consumed letter-by-letter.
            TextField("", text: $inputBuffer)
                .focused($inputFocused)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .frame(width: 1, height: 1)
                .opacity(0.02) // effectively invisible but still focusable
                .onChange(of: inputBuffer) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    for character in newValue {
                        handle(character)
                    }
                    inputBuffer = "" // consume; deletes on empty are no-ops
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = true } // re-summon the keyboard if dismissed
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            startAlarm()
            // Safety fallback: never hold the screen for more than 30 seconds.
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
                Task { @MainActor in dismissChallenge(success: false) }
            }
            // Focus after presentation settles so the keyboard reliably appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                inputFocused = true
            }
        }
        .onDisappear { teardown() }
    }

    // MARK: - Typing (same rules as the macOS key handler)

    private func handle(_ character: Character) {
        guard let typed = String(character).uppercased().first, typed.isLetter else {
            return // digits, punctuation, etc.: neither advance nor reset
        }

        let word = Array(request.challengeWord.uppercased())
        if typedCount < word.count && typed == word[typedCount] {
            typedCount += 1
            if typedCount == word.count {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                AudioServicesPlaySystemSound(1001) // mail-sent swoosh as the "Hero" stand-in
                dismissChallenge(success: true)
            }
        } else {
            // Wrong letter: reset progress, error haptic + error tone
            typedCount = 0
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            AudioServicesPlaySystemSound(1073) // ct-error tone as the "Basso" stand-in
        }
    }

    // MARK: - Alarm

    private func startAlarm() {
        AudioServicesPlaySystemSound(alarmSoundID)
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(alarmSoundID)
        }
    }

    private func teardown() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }

    private func dismissChallenge(success: Bool) {
        teardown()
        onDismiss()
    }

    // MARK: - Labels (formatting copied from OverlayContentView.configure)

    private func countdownText(now: Date) -> String {
        let remaining = request.startDate.timeIntervalSince(now)
        guard remaining > 0 else { return "NOW" }
        let totalSeconds = Int(remaining)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var startTimeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: request.startDate)
    }

    private var durationText: String {
        let duration = Int(request.endDate.timeIntervalSince(request.startDate) / 60)
        if duration >= 60 {
            let hours = duration / 60
            let mins = duration % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours) hour\(hours > 1 ? "s" : "")"
        }
        return "\(duration) minutes"
    }
}
