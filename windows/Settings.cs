using System.IO;
using System.Text.Json;

namespace FocusBlock;

/// <summary>
/// User settings persisted to %APPDATA%\FocusBlock\settings.json.
/// </summary>
public sealed class Settings
{
    /// <summary>ICS subscription URL (e.g. Google Calendar "Secret address in iCal format").</summary>
    public string CalendarUrl { get; set; } = "";

    /// <summary>Which alert windows are enabled, in minutes before the event (30, 10, 5).</summary>
    public List<int> EnabledWindows { get; set; } = new() { 30, 10, 5 };

    private static string Dir =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "FocusBlock");

    private static string FilePath => Path.Combine(Dir, "settings.json");

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static Settings Load()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                var loaded = JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath));
                if (loaded != null)
                {
                    // Keep only valid window values (guard against explicit null in JSON).
                    loaded.CalendarUrl ??= "";
                    loaded.EnabledWindows = (loaded.EnabledWindows ?? new List<int>())
                        .Where(w => w is 30 or 10 or 5)
                        .Distinct()
                        .ToList();
                    return loaded;
                }
            }
        }
        catch
        {
            // Corrupt or unreadable settings: fall back to defaults.
        }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Dir);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, JsonOptions));
        }
        catch
        {
            // Non-fatal: settings just won't persist this time.
        }
    }
}
