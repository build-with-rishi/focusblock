using System.Globalization;
using System.Text;

namespace FocusBlock;

/// <summary>
/// One parsed VEVENT. Start/End are always local time (DateTimeKind.Local).
/// </summary>
public sealed class CalendarEvent
{
    public string Uid { get; init; } = "";
    public string Summary { get; init; } = "";
    public DateTime Start { get; init; }
    public DateTime End { get; init; }
    public bool IsAllDay { get; init; }
}

/// <summary>
/// Minimal iCalendar (RFC 5545) parser, just enough for calendar-feed reminders:
/// - RFC line unfolding (continuation lines start with space or tab)
/// - DTSTART/DTEND in UTC ("...Z"), with TZID parameter, floating local time,
///   and all-day VALUE=DATE form
/// - SUMMARY text unescaping (\n \, \; \\)
/// - skips STATUS:CANCELLED events and VALARM sub-components
///
/// Caveat: RRULE recurrence is NOT expanded. A recurring event contributes only
/// its literal DTSTART (the first occurrence in the feed). Google Calendar's
/// secret ICS feed lists recurring events as RRULEs, so later occurrences of a
/// recurring series will not trigger overlays.
/// </summary>
public static class IcsParser
{
    public static List<CalendarEvent> Parse(string ics)
    {
        var events = new List<CalendarEvent>();

        bool inEvent = false;
        bool inAlarm = false;
        string uid = "", summary = "", status = "";
        (DateTime Value, bool IsAllDay)? start = null, end = null;

        foreach (var line in Unfold(ics))
        {
            var (name, parameters, value) = ParseContentLine(line);

            if (name == "BEGIN")
            {
                if (value.Equals("VEVENT", StringComparison.OrdinalIgnoreCase))
                {
                    inEvent = true;
                    inAlarm = false;
                    uid = ""; summary = ""; status = "";
                    start = null; end = null;
                }
                else if (inEvent && value.Equals("VALARM", StringComparison.OrdinalIgnoreCase))
                {
                    // VALARM blocks may contain their own SUMMARY; ignore them entirely.
                    inAlarm = true;
                }
                continue;
            }

            if (name == "END")
            {
                if (inAlarm && value.Equals("VALARM", StringComparison.OrdinalIgnoreCase))
                {
                    inAlarm = false;
                }
                else if (inEvent && value.Equals("VEVENT", StringComparison.OrdinalIgnoreCase))
                {
                    if (start.HasValue &&
                        !status.Equals("CANCELLED", StringComparison.OrdinalIgnoreCase))
                    {
                        var (startValue, isAllDay) = start.Value;
                        var endValue = end?.Value
                            ?? (isAllDay ? startValue.AddDays(1) : startValue.AddHours(1));
                        if (endValue <= startValue)
                        {
                            endValue = isAllDay ? startValue.AddDays(1) : startValue.AddHours(1);
                        }

                        events.Add(new CalendarEvent
                        {
                            Uid = uid.Length > 0
                                ? uid
                                : $"{summary}|{startValue:yyyyMMddTHHmmss}",
                            Summary = summary,
                            Start = startValue,
                            End = endValue,
                            IsAllDay = isAllDay
                        });
                    }
                    inEvent = false;
                }
                continue;
            }

            if (!inEvent || inAlarm) continue;

            switch (name)
            {
                case "UID":
                    uid = value.Trim();
                    break;
                case "SUMMARY":
                    summary = UnescapeText(value).Trim();
                    break;
                case "STATUS":
                    status = value.Trim();
                    break;
                case "DTSTART":
                    start = ParseIcsDateTime(value, parameters);
                    break;
                case "DTEND":
                    end = ParseIcsDateTime(value, parameters);
                    break;
            }
        }

        events.Sort((a, b) => a.Start.CompareTo(b.Start));
        return events;
    }

    /// <summary>RFC 5545 line unfolding: a line starting with SPACE/TAB continues the previous line.</summary>
    private static IEnumerable<string> Unfold(string ics)
    {
        var rawLines = ics.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        string? current = null;

        foreach (var raw in rawLines)
        {
            if (raw.Length > 0 && (raw[0] == ' ' || raw[0] == '\t'))
            {
                if (current != null) current += raw[1..];
            }
            else
            {
                if (!string.IsNullOrEmpty(current)) yield return current;
                current = raw;
            }
        }
        if (!string.IsNullOrEmpty(current)) yield return current;
    }

    /// <summary>
    /// Splits "NAME;PARAM=V;PARAM2="quoted":VALUE" into its parts, honoring
    /// double quotes (a ':' or ';' inside quotes is literal).
    /// </summary>
    private static (string Name, Dictionary<string, string> Parameters, string Value) ParseContentLine(string line)
    {
        int colon = -1;
        bool inQuotes = false;
        for (int i = 0; i < line.Length; i++)
        {
            char c = line[i];
            if (c == '"') inQuotes = !inQuotes;
            else if (c == ':' && !inQuotes) { colon = i; break; }
        }

        var parameters = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (colon < 0)
        {
            return (line.Trim().ToUpperInvariant(), parameters, "");
        }

        string left = line[..colon];
        string value = line[(colon + 1)..];

        var parts = SplitOutsideQuotes(left, ';');
        string name = parts[0].Trim().ToUpperInvariant();

        for (int i = 1; i < parts.Count; i++)
        {
            int eq = parts[i].IndexOf('=');
            if (eq > 0)
            {
                string paramName = parts[i][..eq].Trim().ToUpperInvariant();
                string paramValue = parts[i][(eq + 1)..].Trim().Trim('"');
                parameters[paramName] = paramValue;
            }
        }
        return (name, parameters, value);
    }

    private static List<string> SplitOutsideQuotes(string text, char separator)
    {
        var parts = new List<string>();
        var sb = new StringBuilder();
        bool inQuotes = false;
        foreach (char c in text)
        {
            if (c == '"') { inQuotes = !inQuotes; sb.Append(c); }
            else if (c == separator && !inQuotes) { parts.Add(sb.ToString()); sb.Clear(); }
            else sb.Append(c);
        }
        parts.Add(sb.ToString());
        return parts;
    }

    /// <summary>
    /// Parses an ICS date/datetime value into local time.
    /// Handles: 20260611 (all-day), 20260611T140000Z (UTC),
    /// 20260611T100000 with TZID parameter, and floating local time.
    /// </summary>
    private static (DateTime Value, bool IsAllDay)? ParseIcsDateTime(string value, Dictionary<string, string> parameters)
    {
        value = value.Trim();
        if (value.Length == 0) return null;

        bool dateOnly =
            (parameters.TryGetValue("VALUE", out var valueType) &&
             valueType.Equals("DATE", StringComparison.OrdinalIgnoreCase))
            || (value.Length == 8 && value.All(char.IsDigit));

        if (dateOnly)
        {
            if (DateTime.TryParseExact(value, "yyyyMMdd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var date))
            {
                return (DateTime.SpecifyKind(date, DateTimeKind.Local), true);
            }
            return null;
        }

        bool isUtc = value.EndsWith("Z", StringComparison.Ordinal);
        string core = isUtc ? value[..^1] : value;

        if (!DateTime.TryParseExact(core, "yyyyMMdd'T'HHmmss", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var dt) &&
            !DateTime.TryParseExact(core, "yyyyMMdd'T'HHmm", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out dt))
        {
            return null;
        }

        if (isUtc)
        {
            return (DateTime.SpecifyKind(dt, DateTimeKind.Utc).ToLocalTime(), false);
        }

        if (parameters.TryGetValue("TZID", out var tzid))
        {
            try
            {
                // .NET 8 on Windows 10+ resolves both IANA ("America/New_York")
                // and Windows ("Eastern Standard Time") time zone ids.
                var tz = TimeZoneInfo.FindSystemTimeZoneById(tzid);
                var utc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(dt, DateTimeKind.Unspecified), tz);
                return (utc.ToLocalTime(), false);
            }
            catch
            {
                // Unknown time zone id: fall through and treat as local time.
            }
        }

        // Floating time: interpret as local.
        return (DateTime.SpecifyKind(dt, DateTimeKind.Local), false);
    }

    /// <summary>RFC 5545 TEXT unescaping: \n and \N to newline, \, \; \\ to literal.</summary>
    private static string UnescapeText(string text)
    {
        var sb = new StringBuilder(text.Length);
        for (int i = 0; i < text.Length; i++)
        {
            if (text[i] == '\\' && i + 1 < text.Length)
            {
                i++;
                sb.Append(text[i] is 'n' or 'N' ? '\n' : text[i]);
            }
            else
            {
                sb.Append(text[i]);
            }
        }
        return sb.ToString();
    }
}
