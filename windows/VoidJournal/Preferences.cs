using System.IO;
using System.Text.Json;

namespace VoidJournal;

public sealed class Preferences
{
    public string Theme { get; set; } = "Void";
    public string Appearance { get; set; } = "System";
    public string Typeface { get; set; } = "Serif";
    public int TextSize { get; set; } = 28;
    public bool MovingGradients { get; set; } = true;
    public bool HasSeenIntro { get; set; }
    private static string PathName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VoidJournal", "preferences.json");
    public static Preferences Load()
    {
        try
        {
            var p = JsonSerializer.Deserialize<Preferences>(File.ReadAllText(PathName)) ?? new();
            if (p.Theme is not ("Void" or "Dissolve")) p.Theme = "Void";
            if (p.Appearance is not ("System" or "Light" or "Dark")) p.Appearance = "System";
            if (p.Typeface is not ("Serif" or "Sans Serif" or "Monospaced")) p.Typeface = "Serif";
            if (p.TextSize is not (18 or 22 or 28 or 34)) p.TextSize = 28;
            return p;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { return new(); }
    }
    public bool Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(PathName)!);
            File.WriteAllText(PathName, JsonSerializer.Serialize(this));
            return true;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return false; }
    }
}
