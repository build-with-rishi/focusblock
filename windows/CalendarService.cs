using System.Net.Http;
using System.Windows.Threading;

namespace FocusBlock;

/// <summary>
/// Polls the configured ICS subscription URL every 5 minutes and checks the
/// cached events every 60 seconds for the 30/10/5-minutes-before trigger
/// windows. Each (event UID, window) pair fires at most once.
///
/// All timers run on the WPF dispatcher thread, so no locking is needed.
/// </summary>
public sealed class CalendarService
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    private readonly Settings _settings;
    private readonly Action<CalendarEvent, int> _onTrigger;

    private List<CalendarEvent> _events = new();
    private readonly HashSet<string> _shownTriggers = new();
    private DispatcherTimer? _pollTimer;
    private DispatcherTimer? _checkTimer;

    public DateTime? LastSuccessfulFetch { get; private set; }
    public string? LastError { get; private set; }

    public CalendarService(Settings settings, Action<CalendarEvent, int> onTrigger)
    {
        _settings = settings;
        _onTrigger = onTrigger;
    }

    public bool HasUrl => !string.IsNullOrWhiteSpace(_settings.CalendarUrl);

    public void Start()
    {
        _ = RefreshNowAsync();

        _pollTimer = new DispatcherTimer { Interval = TimeSpan.FromMinutes(5) };
        _pollTimer.Tick += async (_, _) => await RefreshAsync();
        _pollTimer.Start();

        _checkTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(60) };
        _checkTimer.Tick += (_, _) => CheckTriggers();
        _checkTimer.Start();
    }

    /// <summary>Re-fetches the feed immediately (used after the URL changes).</summary>
    public async Task RefreshNowAsync()
    {
        await RefreshAsync();
        CheckTriggers();
    }

    private async Task RefreshAsync()
    {
        var url = _settings.CalendarUrl;
        if (string.IsNullOrWhiteSpace(url))
        {
            _events = new List<CalendarEvent>();
            return;
        }

        try
        {
            string ics = await Http.GetStringAsync(url);
            _events = IcsParser.Parse(ics);
            LastSuccessfulFetch = DateTime.Now;
            LastError = null;
        }
        catch (Exception ex)
        {
            // Network or parse failure: keep the last good cache so triggers
            // still fire from previously fetched events.
            LastError = ex.Message;
        }
    }

    private void CheckTriggers()
    {
        var now = DateTime.Now;

        foreach (var ev in _events)
        {
            double minutesUntil = (ev.Start - now).TotalMinutes;
            if (minutesUntil < 0 || minutesUntil > 35) continue;

            foreach (int window in _settings.EnabledWindows.ToArray())
            {
                // Same +/-1 minute tolerance as the macOS version, so a 60s
                // check cadence can never skip over a window.
                if (minutesUntil >= window - 1 && minutesUntil <= window + 1)
                {
                    string key = $"{ev.Uid}|{window}";
                    if (_shownTriggers.Add(key))
                    {
                        _onTrigger(ev, window);
                    }
                }
            }
        }
    }

    /// <summary>The next event starting within the coming 24 hours, if any.</summary>
    public CalendarEvent? NextEvent()
    {
        var now = DateTime.Now;
        var horizon = now.AddHours(24);
        return _events
            .Where(e => e.Start > now && e.Start <= horizon)
            .OrderBy(e => e.Start)
            .FirstOrDefault();
    }
}
