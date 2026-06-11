using Microsoft.Win32;

namespace FocusBlock;

/// <summary>
/// Launch-at-login via the per-user registry Run key
/// (HKCU\Software\Microsoft\Windows\CurrentVersion\Run). No admin rights needed.
/// </summary>
public static class LaunchAtLogin
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "FocusBlock";

    public static bool IsEnabled
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
                return key?.GetValue(ValueName) != null;
            }
            catch
            {
                return false;
            }
        }
        set
        {
            try
            {
                using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
                if (key == null) return;

                if (value)
                {
                    string? exePath = Environment.ProcessPath;
                    if (!string.IsNullOrEmpty(exePath))
                    {
                        key.SetValue(ValueName, $"\"{exePath}\"");
                    }
                }
                else
                {
                    key.DeleteValue(ValueName, throwOnMissingValue: false);
                }
            }
            catch
            {
                // Registry write failed (policy-restricted machine): ignore.
            }
        }
    }
}
