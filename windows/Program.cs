using System.Windows;

namespace FocusBlock;

/// <summary>
/// Entry point. FocusBlock is a tray-only app: a WPF Application provides the
/// dispatcher/message loop (which also services the WinForms NotifyIcon), but
/// no main window is ever created. Overlay windows appear only when a
/// calendar trigger fires.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main()
    {
        var app = new Application
        {
            // No main window; the app lives until Quit is chosen in the tray menu.
            ShutdownMode = ShutdownMode.OnExplicitShutdown
        };

        var settings = Settings.Load();
        var overlay = new OverlayController();
        var calendar = new CalendarService(settings, (ev, minutes) => overlay.ShowOverlay(ev, minutes));
        using var tray = new TrayIcon(settings, calendar, overlay, app);

        calendar.Start();
        app.Run();
    }
}
