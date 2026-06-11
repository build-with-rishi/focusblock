using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;

namespace FocusBlock;

/// <summary>
/// One full-screen black overlay window per monitor: borderless, topmost,
/// hidden from the taskbar, and positioned with SetWindowPos in physical
/// pixels so it covers the entire monitor under Per-Monitor V2 DPI awareness.
///
/// Layout (top to bottom, centered): event title (medium), time-to-event
/// (huge bold — the dominant element), start time · duration (small), a quote
/// (italic), and the challenge word spaced out letter by letter. Typed letters
/// light up white. Clicking does nothing; only typing the word dismisses it.
/// </summary>
public sealed class OverlayWindow : Window
{
    /// <summary>Raised with an uppercase letter A-Z whenever one is typed.</summary>
    public event Action<char>? LetterTyped;

    private readonly System.Drawing.Rectangle _physicalBounds;
    private readonly List<TextBlock> _letterBlocks = new();
    private bool _allowClose;

    private readonly TextBlock _titleText;
    private readonly TextBlock _timeText;
    private readonly TextBlock _startDurationText;
    private readonly TextBlock _quoteText;
    private readonly StackPanel _challengePanel;

    private static readonly Brush DimLetterBrush = Gray(71);

    public OverlayWindow(System.Drawing.Rectangle physicalBounds)
    {
        _physicalBounds = physicalBounds;

        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        Background = Brushes.Black;
        Topmost = true;
        ShowInTaskbar = false;
        ShowActivated = true;
        Focusable = true;
        WindowStartupLocation = WindowStartupLocation.Manual;

        // Rough initial placement so WPF creates the window near the target
        // monitor; OnSourceInitialized snaps it to the exact physical bounds.
        Left = physicalBounds.Left;
        Top = physicalBounds.Top;
        Width = 200;
        Height = 200;

        _titleText = CenteredText(34, FontWeights.SemiBold, Gray(217));
        _titleText.Margin = new Thickness(60, 0, 60, 28);
        _titleText.TextTrimming = TextTrimming.CharacterEllipsis;

        _timeText = CenteredText(96, FontWeights.Heavy, Brushes.White);
        _timeText.Margin = new Thickness(0, 0, 0, 12);

        _startDurationText = CenteredText(18, FontWeights.Normal, Gray(102));
        _startDurationText.Margin = new Thickness(0, 0, 0, 48);

        _quoteText = CenteredText(26, FontWeights.Medium, Gray(204));
        _quoteText.FontStyle = FontStyles.Italic;
        _quoteText.TextWrapping = TextWrapping.Wrap;
        _quoteText.TextAlignment = TextAlignment.Center;
        _quoteText.MaxWidth = 860;
        _quoteText.Margin = new Thickness(0, 0, 0, 64);

        _challengePanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center
        };

        var stack = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        stack.Children.Add(_titleText);
        stack.Children.Add(_timeText);
        stack.Children.Add(_startDurationText);
        stack.Children.Add(_quoteText);
        stack.Children.Add(_challengePanel);

        var hint = CenteredText(13, FontWeights.Normal, Gray(77));
        hint.Text = "type the word above to dismiss";
        hint.VerticalAlignment = VerticalAlignment.Bottom;
        hint.Margin = new Thickness(0, 0, 0, 40);

        var root = new Grid { Background = Brushes.Black };
        root.Children.Add(stack);
        root.Children.Add(hint);
        Content = root;

        // WPF may apply DIP-based sizing after the HWND exists, so the bounds
        // are asserted both at SourceInitialized and again at Loaded.
        Loaded += (_, _) => ApplyPhysicalBounds();
    }

    public void Configure(CalendarEvent ev, int minutesBefore, string quote, string challengeWord)
    {
        _titleText.Text = string.IsNullOrWhiteSpace(ev.Summary) ? "Upcoming Event" : ev.Summary;

        _timeText.Text = minutesBefore switch
        {
            30 => "30 minutes",
            10 => "10 minutes",
            5 => "5 minutes",
            _ => "starting soon"
        };

        string startLabel = ev.Start.ToString("t"); // short time, current culture
        int durationMinutes = (int)(ev.End - ev.Start).TotalMinutes;
        string durationLabel;
        if (durationMinutes >= 60)
        {
            int hours = durationMinutes / 60;
            int mins = durationMinutes % 60;
            durationLabel = mins > 0 ? $"{hours}h {mins}m" : $"{hours} hour{(hours > 1 ? "s" : "")}";
        }
        else
        {
            durationLabel = $"{durationMinutes} minutes";
        }
        _startDurationText.Text = $"{startLabel}  ·  {durationLabel}";

        _quoteText.Text = $"“{quote}”";

        _letterBlocks.Clear();
        _challengePanel.Children.Clear();
        foreach (char letter in challengeWord.ToUpperInvariant())
        {
            var block = new TextBlock
            {
                Text = letter.ToString(),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 40,
                FontWeight = FontWeights.Bold,
                Foreground = DimLetterBrush,
                Margin = new Thickness(7, 0, 7, 0)
            };
            _letterBlocks.Add(block);
            _challengePanel.Children.Add(block);
        }
    }

    /// <summary>Lights up the first <paramref name="typedCount"/> letters in white.</summary>
    public void UpdateTyped(int typedCount)
    {
        for (int i = 0; i < _letterBlocks.Count; i++)
        {
            _letterBlocks[i].Foreground = i < typedCount ? Brushes.White : DimLetterBrush;
        }
    }

    public void ForceClose()
    {
        _allowClose = true;
        Close();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        ApplyPhysicalBounds();
    }

    /// <summary>
    /// Covers the monitor exactly, in physical pixels. SetWindowPos bypasses
    /// WPF's DIP coordinate conversion entirely, so this is correct under
    /// Per-Monitor V2 DPI with any mix of scale factors.
    /// </summary>
    private void ApplyPhysicalBounds()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        if (hwnd == IntPtr.Zero) return;
        NativeMethods.SetWindowPos(
            hwnd,
            NativeMethods.HWND_TOPMOST,
            _physicalBounds.X,
            _physicalBounds.Y,
            _physicalBounds.Width,
            _physicalBounds.Height,
            NativeMethods.SWP_SHOWWINDOW);
    }

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if (e.Key >= Key.A && e.Key <= Key.Z)
        {
            LetterTyped?.Invoke((char)('A' + (e.Key - Key.A)));
            e.Handled = true;
        }
        // Anything else (Esc, arrows, modifiers...) neither advances nor
        // resets progress — same behavior as the macOS version.
        base.OnPreviewKeyDown(e);
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        // Block Alt+F4 and any other close path except ForceClose().
        if (!_allowClose) e.Cancel = true;
        base.OnClosing(e);
    }

    private static TextBlock CenteredText(double size, FontWeight weight, Brush brush) => new()
    {
        FontSize = size,
        FontWeight = weight,
        Foreground = brush,
        HorizontalAlignment = HorizontalAlignment.Center
    };

    private static SolidColorBrush Gray(byte value)
    {
        var brush = new SolidColorBrush(Color.FromRgb(value, value, value));
        brush.Freeze();
        return brush;
    }

    private static class NativeMethods
    {
        public static readonly IntPtr HWND_TOPMOST = new(-1);
        public const uint SWP_SHOWWINDOW = 0x0040;

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(
            IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint flags);
    }
}
