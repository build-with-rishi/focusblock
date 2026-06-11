using System.IO;
using System.Media;
using System.Windows.Threading;

namespace FocusBlock;

/// <summary>
/// Loops a native Windows alarm sound while an overlay is up.
/// Prefers the stock alarm tones shipped in C:\Windows\Media (Alarm01.wav
/// first), falling back through a candidate list. If no candidate file is
/// found or playable, falls back to a repeating system exclamation beep so
/// the alarm is never silent.
/// </summary>
public sealed class AlarmPlayer
{
    private static readonly string[] Candidates =
    {
        "Alarm01.wav",
        "Alarm02.wav",
        "Alarm03.wav",
        "Alarm05.wav",
        "Alarm10.wav",
        "Ring01.wav",
        "Ring05.wav",
        "Windows Notify Calendar.wav",
        "notify.wav",
        "tada.wav"
    };

    private SoundPlayer? _player;
    private DispatcherTimer? _fallbackTimer;

    public void Start()
    {
        Stop();

        string mediaDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Media");

        foreach (string candidate in Candidates)
        {
            string path = Path.Combine(mediaDir, candidate);
            if (!File.Exists(path)) continue;
            try
            {
                var player = new SoundPlayer(path);
                player.PlayLooping();
                _player = player;
                return;
            }
            catch
            {
                // Unreadable/corrupt file: try the next candidate.
            }
        }

        // Last resort: beep every 2 seconds until dismissed.
        SystemSounds.Exclamation.Play();
        _fallbackTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _fallbackTimer.Tick += (_, _) => SystemSounds.Exclamation.Play();
        _fallbackTimer.Start();
    }

    public void Stop()
    {
        if (_player != null)
        {
            try { _player.Stop(); } catch { }
            _player.Dispose();
            _player = null;
        }
        _fallbackTimer?.Stop();
        _fallbackTimer = null;
    }
}
