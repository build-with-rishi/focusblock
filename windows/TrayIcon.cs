using System.Windows.Forms;

namespace FocusBlock;

/// <summary>
/// System tray icon and context menu (the app's only persistent UI):
/// next-event info, Test Overlay, 30/10/5 alert-window toggles,
/// Set Calendar URL…, Launch at Login, Quit.
/// </summary>
public sealed class TrayIcon : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Settings _settings;
    private readonly CalendarService _calendar;
    private readonly OverlayController _overlay;
    private readonly System.Windows.Application _app;
    private readonly ToolStripMenuItem _nextEventItem;
    private readonly ToolStripMenuItem _launchAtLoginItem;

    public TrayIcon(Settings settings, CalendarService calendar, OverlayController overlay,
        System.Windows.Application app)
    {
        _settings = settings;
        _calendar = calendar;
        _overlay = overlay;
        _app = app;

        var menu = new ContextMenuStrip();

        _nextEventItem = new ToolStripMenuItem("No upcoming events") { Enabled = false };
        menu.Items.Add(_nextEventItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(new ToolStripMenuItem("Test Overlay", null, (_, _) => _overlay.TestOverlay()));
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(new ToolStripMenuItem("Alert Windows") { Enabled = false });
        foreach (int minutes in new[] { 30, 10, 5 })
        {
            int m = minutes; // capture per iteration
            var item = new ToolStripMenuItem($"{m} minutes before")
            {
                Checked = _settings.EnabledWindows.Contains(m)
            };
            item.Click += (_, _) => ToggleWindow(m, item);
            menu.Items.Add(item);
        }
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(new ToolStripMenuItem("Set Calendar URL…", null, (_, _) => SetCalendarUrl()));

        _launchAtLoginItem = new ToolStripMenuItem("Launch at Login")
        {
            Checked = LaunchAtLogin.IsEnabled
        };
        _launchAtLoginItem.Click += (_, _) => ToggleLaunchAtLogin();
        menu.Items.Add(_launchAtLoginItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(new ToolStripMenuItem("Quit FocusBlock", null, (_, _) => Quit()));

        // Refresh the next-event line every time the menu opens.
        menu.Opening += (_, _) => RefreshNextEventItem();

        _notifyIcon = new NotifyIcon
        {
            Icon = System.Drawing.SystemIcons.Application,
            Text = "FocusBlock",
            Visible = true,
            ContextMenuStrip = menu
        };
    }

    private void RefreshNextEventItem()
    {
        if (!_calendar.HasUrl)
        {
            _nextEventItem.Text = "No calendar URL set";
            return;
        }

        var ev = _calendar.NextEvent();
        if (ev == null)
        {
            _nextEventItem.Text = _calendar.LastError != null && _calendar.LastSuccessfulFetch == null
                ? "Calendar fetch failed"
                : "No upcoming events";
            return;
        }

        string title = string.IsNullOrWhiteSpace(ev.Summary) ? "Event" : ev.Summary;
        if (title.Length > 40) title = title[..40] + "…";
        _nextEventItem.Text = $"Next: {title} at {ev.Start:t}";
    }

    private void ToggleWindow(int minutes, ToolStripMenuItem item)
    {
        if (_settings.EnabledWindows.Contains(minutes))
        {
            _settings.EnabledWindows.Remove(minutes);
            item.Checked = false;
        }
        else
        {
            _settings.EnabledWindows.Add(minutes);
            item.Checked = true;
        }
        _settings.Save();
    }

    private void SetCalendarUrl()
    {
        var dialog = new InputDialog(
            "Set Calendar URL",
            "Paste your calendar's ICS (iCal) subscription URL.\n" +
            "Google Calendar: Settings → your calendar → \"Secret address in iCal format\".",
            _settings.CalendarUrl);

        if (dialog.ShowDialog() == true)
        {
            string url = dialog.Value.Trim();
            if (url.StartsWith("webcal://", StringComparison.OrdinalIgnoreCase))
            {
                url = "https://" + url["webcal://".Length..];
            }
            _settings.CalendarUrl = url;
            _settings.Save();
            _ = _calendar.RefreshNowAsync();
        }
    }

    private void ToggleLaunchAtLogin()
    {
        LaunchAtLogin.IsEnabled = !LaunchAtLogin.IsEnabled;
        _launchAtLoginItem.Checked = LaunchAtLogin.IsEnabled;
    }

    private void Quit()
    {
        _overlay.DismissAll();
        _notifyIcon.Visible = false;
        _app.Shutdown();
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
    }
}
