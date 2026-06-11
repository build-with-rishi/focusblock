using System.Media;
using System.Windows.Threading;

namespace FocusBlock;

/// <summary>
/// Shows/dismisses the full-screen overlays. One OverlayWindow per connected
/// monitor; all share the same challenge word and quote. Keyboard input from
/// whichever window has focus updates the challenge state on every window.
/// A looping alarm plays the whole time; a wrong letter resets progress with
/// an error sound; typing the full word dismisses with a success sound.
/// A 30-second auto-dismiss timer is the safety fallback.
/// </summary>
public sealed class OverlayController
{
    private readonly List<OverlayWindow> _windows = new();
    private readonly AlarmPlayer _alarm = new();
    private DispatcherTimer? _autoDismissTimer;
    private string _challengeWord = "";
    private int _typedCount;

    private static readonly Random Rng = new();

    private static readonly string[] ChallengeWords =
    {
        "FOCUS", "COMMIT", "BEGIN", "ARRIVE", "PRESENT",
        "DELIVER", "ENGAGE", "PREPARE", "SHOWUP", "READY"
    };

    private static readonly string[] Quotes =
    {
        "This meeting happens with or without your attention. Choose with.",
        "Stop negotiating with yourself. Wrap up and show up.",
        "You said yes to this. Honor it.",
        "Avoiding it won't cancel it.",
        "Five minutes of prep beats thirty minutes of apologizing.",
        "Close the tabs. The meeting is the work now.",
        "You don't need motivation. You need to stand up.",
        "Every minute you stall, the meeting gets harder.",
        "The dread dies the moment you start moving.",
        "Showing up late is a decision. So is showing up ready.",
        "Discomfort now or regret later. Pick one.",
        "You're not in flow. You're avoiding.",
        "Stop scrolling. Start moving.",
        "Finish the sentence, save the file, go.",
        "The work will wait. The meeting won't.",
        "Your future self is begging you to get up now.",
        "Nothing on your screen matters more than the next hour.",
        "Be the person who walks in prepared.",
        "Procrastination is fear wearing comfortable clothes.",
        "Win the hour by walking in ready."
    };

    public void ShowOverlay(CalendarEvent ev, int minutesBefore)
    {
        DismissAll(); // clean up any existing overlays first

        _challengeWord = ChallengeWords[Rng.Next(ChallengeWords.Length)];
        _typedCount = 0;
        string quote = Quotes[Rng.Next(Quotes.Length)];

        OverlayWindow? primaryWindow = null;
        foreach (var screen in System.Windows.Forms.Screen.AllScreens)
        {
            var window = new OverlayWindow(screen.Bounds);
            window.Configure(ev, minutesBefore, quote, _challengeWord);
            window.LetterTyped += HandleLetter;
            _windows.Add(window);
            window.Show();
            if (screen.Primary) primaryWindow = window;
        }

        // Give one window keyboard focus; its key events drive all of them.
        var focusTarget = primaryWindow ?? _windows.FirstOrDefault();
        focusTarget?.Activate();
        focusTarget?.Focus();

        _alarm.Start();

        // Safety fallback: never leave the screens locked for more than 30s.
        _autoDismissTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
        _autoDismissTimer.Tick += (_, _) => DismissAll();
        _autoDismissTimer.Start();
    }

    private void HandleLetter(char typed)
    {
        if (_typedCount < _challengeWord.Length && typed == _challengeWord[_typedCount])
        {
            _typedCount++;
            if (_typedCount == _challengeWord.Length)
            {
                DismissAll();
                SystemSounds.Asterisk.Play(); // success
                return;
            }
        }
        else
        {
            _typedCount = 0;
            SystemSounds.Hand.Play(); // error: progress resets
        }

        foreach (var window in _windows)
        {
            window.UpdateTyped(_typedCount);
        }
    }

    public void DismissAll()
    {
        _alarm.Stop();
        _autoDismissTimer?.Stop();
        _autoDismissTimer = null;

        foreach (var window in _windows)
        {
            window.LetterTyped -= HandleLetter;
            window.ForceClose();
        }
        _windows.Clear();
        _typedCount = 0;
    }

    public void TestOverlay()
    {
        var mockEvent = new CalendarEvent
        {
            Uid = "test-overlay",
            Summary = "Test Event",
            Start = DateTime.Now.AddMinutes(10),
            End = DateTime.Now.AddMinutes(55)
        };
        ShowOverlay(mockEvent, 10);
    }
}
